# this needs to be done in JS land to avoid creating a global var module
`
if (typeof module === 'undefined') {
  exports = {};
  module = { exports: exports };
  require = function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  }
}
`

async = require('async')
driverUtil = require('./driverUtil')

# -----------------------------------------------------

# Open source Druid issues:
# - add limit to groupBy

makeFilter = (attribute, value) ->
  if Array.isArray(value)
    return { type: 'within', attribute, range: value }
  else
    return { type: 'is', attribute, value }

andFilters = (filters...) ->
  filters = filters.filter((filter) -> filter?)
  switch filters.length
    when 0
      return null
    when 1
      return filters[0]
    else
      return { type: 'and', filters }

rangeToDruidInterval = (interval) ->
  return interval.map((d) -> d.toISOString().replace('Z', '')).join('/')


class DruidQueryBuilder
  @allTimeInterval = ["1000-01-01/3000-01-01"]

  constructor: (@dataSource, @timeAttribute, @forceInterval) ->
    throw new Error("must have a dataSource") unless typeof @dataSource is 'string'
    throw new Error("must have a timeAttribute") unless typeof @timeAttribute is 'string'
    @queryType = 'timeseries'
    @granularity = 'all'
    @filter = null
    @aggregations = []
    @postAggregations = []
    @nameIndex = 0
    @intervals = null

  dateToIntervalPart: (date) ->
    return date.toISOString()
      .replace('Z',    '') # remove Z
      .replace('.000', '') # millis if 0
      .replace(/:00$/, '') # remove seconds if 0
      .replace(/:00$/, '') # remove minutes if 0
      .replace(/T00$/, '') # remove hours if 0

  unionIntervals: (intervals) ->
    null # ToDo

  intersectIntervals: (intervals) ->
    return driverUtil.flatten(intervals).filter((d) -> d?) # ToDo: rewrite this to actually work

  # return a (up to) two element array [druid_filter_object, druid_intervals_array]
  filterToDruid: (filter) ->
    switch filter.type
      when 'is'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        [{
          type: 'selector'
          dimension: filter.attribute
          value: filter.value
        }]

      when 'in'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        [{
          type: 'or'
          fields: filter.values.map(((value) ->
            return {
              type: 'selector'
              dimension: filter.attribute
              value
            }
          ), this)
        }]

      when 'fragments'
        throw "todo"

      when 'match'
        throw new Error("can not match filter time") if filter.attribute is @timeAttribute
        [{
          type: "regex"
          dimension: filter.attribute
          pattern: filter.expression
        }]

      when 'within'
        [r0, r1] = filter.range
        if filter.attribute is @timeAttribute
          r0 = new Date(r0) if typeof r0 is 'string'
          r1 = new Date(r1) if typeof r1 is 'string'
          throw new Error("start and end must be dates") unless r0 instanceof Date and r1 instanceof Date
          throw new Error("invalid dates") if isNaN(r0) or isNaN(r1)
          [
            null,
            ["#{@dateToIntervalPart(r0)}/#{@dateToIntervalPart(r1)}"]
          ]
        else if typeof r0 is 'number' and typeof r1 is 'number'
          [{
            type: 'javascript'
            dimension: filter.attribute
            function: "function(a){return a=~~a,#{r0}<=a&&a<#{r1};}"
          }]
        else
          throw new Error("has to be a numeric range")

      when 'not'
        [f, i] = @filterToDruid(filter.filter)
        throw new Error("can not use a 'not' filter on a time interval") if i
        [{
          type: 'not'
          filed: f
        }]

      when 'and'
        fis = filter.filters.map(@filterToDruid, this)
        [
          {
            type: 'and'
            fields: fis.map((d) -> d[0]).filter((d) -> d?)
          }
          @intersectIntervals(fis.map((d) -> d[1]))
        ]

      when 'or'
        fis = filter.filters.map(@filterToDruid, this)
        for [f, i] in fis
          throw new Error("can not 'or' time... yet") if i # ToDo
        [{
          type: 'or'
          fields: fis.map((d) -> d[0]).filter((d) -> d?)
        }]

      else
        throw new Error("unknown filter type '#{filter.type}'")

  addFilter: (filter) ->
    return unless filter
    [@filter, @intervals] = @filterToDruid(filter)
    return this

  addSplit: (split) ->
    throw new Error("split must have an attribute") unless split.attribute

    if split.attribute is @timeAttribute
      #@queryType stays 'timeseries'
      if split.bucket is 'timePeriod'
        throw new Error("invalid period") unless split.period
        @granularity = {
          type: "period"
          period: split.period
          timeZone: split.timezone
        }
      else if split.bucket is 'timeDuration'
        throw new Error("invalid duration") unless split.duration
        @granularity = {
          type: "duration"
          duration: split.duration
        }
      else
        throw new Error("time can only be bucketed with timePeriod or timeDuration bucketing functions")
    else
      @queryType = 'topN'
      #@granularity stays 'all'
      @dimension = {
        type: 'default'
        dimension: split.attribute
        outputName: split.name
      }
      @threshold = 12
      @metric = null

    return this

  throwawayName: ->
    @nameIndex++
    return "_f#{@nameIndex}"

  isThrowawayName: (name) ->
    return name[0] is '_'

  renameAggregationInPostAgregation: (postAggregation, from, to) ->
    switch postAggregation.type
      when 'fieldAccess', 'quantile'
        if postAggregation.fieldName is from
          postAggregation.fieldName = to

      when 'arithmetic'
        for postAgg in postAggregation.fields
          @renameAggregationInPostAgregation(postAgg, from, to)

      when 'constant'
        null # do nothing

      else
        throw new Error("unsupported postAggregation type '#{postAggregation.type}'")
    return

  addAggregation: (aggregation) ->
    aggregation.name or= @throwawayName()

    for existingAggregation in @aggregations
      if existingAggregation.type is aggregation.type and
         existingAggregation.fieldName is aggregation.fieldName and
         existingAggregation.fieldNames is aggregation.fieldNames and
         existingAggregation.script is aggregation.script and
         (@isThrowawayName(existingAggregation.name) or @isThrowawayName(aggregation.name))

        if @isThrowawayName(aggregation.name)
          # Use the existing aggregation
          return existingAggregation.name
        else
          # We have a throwaway existing aggregation, replace it's name with my non throwaway name
          for postAggregation in @postAggregations
            @renameAggregationInPostAgregation(postAggregation, existingAggregation.name, aggregation.name)
          existingAggregation.name = aggregation.name
          return aggregation.name

    @aggregations.push(aggregation)
    return aggregation.name

  addPostAggregation: (postAggregation) ->
    throw new Error("direct postAggregation must have name") unless postAggregation.name

    # We need this because of an asymmetry in druid, hopefully soon we will be able to remove this.
    if postAggregation.type is 'arithmetic' and not postAggregation.name
      postAggregation.name = @throwawayName()

    @postAggregations.push(postAggregation)
    return



  # This method will ether return a post aggregation or add it.
  addApplyHelper: do ->
    arithmeticToDruidFn = {
      add: '+'
      subtract: '-'
      multiply: '*'
      divide: '/'
    }
    return (apply, returnPostAggregation) ->
      applyName = apply.name or @throwawayName()
      if apply.aggregate
        switch apply.aggregate
          when 'constant'
            postAggregation = {
              type: "constant"
              value: apply.value
            }
            if returnPostAggregation
              return postAggregation
            else
              postAggregation.name = applyName
              @addPostAggregation(postAggregation)
              return

          when 'count', 'sum', 'min', 'max'
            aggregation = {
              type: if apply.aggregate is 'sum' then 'doubleSum' else apply.aggregate
              name: applyName
            }
            if apply.aggregate isnt 'count'
              throw new Error("#{apply.aggregate} must have an attribute") unless apply.attribute
              aggregation.fieldName = apply.attribute

            aggregationName = @addAggregation(aggregation)
            if returnPostAggregation
              return { type: "fieldAccess", fieldName: aggregationName }
            else
              return

          when 'uniqueCount'
            # ToDo: add a throw here in case the user is using open source druid
            aggregation = {
              type: "hyperUnique"
              name: applyName
              fieldName: apply.attribute
            }

            aggregationName = @addAggregation(aggregation)
            if returnPostAggregation
              return { type: "fieldAccess", fieldName: aggregationName }
            else
              return

          when 'average'
            sumAggregationName = @addAggregation {
              type: 'doubleSum'
              fieldName: apply.attribute
            }

            countAggregationName = @addAggregation {
              type: 'count'
            }

            postAggregation = {
              type: "arithmetic"
              fn: "/"
              fields: [
                { type: "fieldAccess", fieldName: sumAggregationName }
                { type: "fieldAccess", fieldName: countAggregationName }
              ]
            }

            if returnPostAggregation
              return postAggregation
            else
              postAggregation.name = applyName
              @addPostAggregation(postAggregation)
              return

          when 'quantile'
            throw new Error("quantile apply must have quantile") unless apply.quantile
            histogramAggregationName = @addAggregation {
              type: "approxHistogramFold"
              fieldName: apply.attribute
            }
            postAggregation = {
              type: "quantile"
              fieldName: histogramAggregationName
              probability: apply.quantile
            }

            if returnPostAggregation
              return postAggregation
            else
              postAggregation.name = applyName
              @addPostAggregation(postAggregation)
              return

          else
            throw new Error("unsupported aggregate '#{apply.aggregate}'")

      else if apply.arithmetic
        druidFn = arithmeticToDruidFn[apply.arithmetic]
        if druidFn
          a = @addApplyHelper(apply.operands[0], true)
          b = @addApplyHelper(apply.operands[1], true)
          postAggregation = {
            type: "arithmetic"
            fn: druidFn
            fields: [a, b]
          }

          if returnPostAggregation
            return postAggregation
          else
            postAggregation.name = applyName
            @addPostAggregation(postAggregation)
            return

        else
          throw new Error("unsupported arithmetic '#{apply.arithmetic}'")

      else
        throw new Error("must have an aggregate or an arithmetic")

  addApply: (apply) ->
    throw new Error("filtered applies are not supported yet") if apply.filter
    @addApplyHelper(apply, false)
    return this

  addDummyApply: ->
    @addApplyHelper({ aggregate: 'count' }, false)
    return this

  addSort: (sort) ->
    if sort.direction not in ['ascending', 'descending']
      throw new Error("direction has to be 'ascending' or 'descending'")

    if @queryType is 'topN'
      if sort.prop is @dimension.outputName
        @metric = { type: "lexicographic" }
      else
        # figure out of we need to invert and apply for a bottomN
        if sort.direction is 'descending'
          @metric = sort.prop
        else
          # make a bottomN
          @addPostAggregation {
            type: "arithmetic"
            name: invertName = @throwawayName()
            fn: "*"
            fields: [
              { type: "fieldAccess", fieldName: sort.prop }
              { type: "constant", value: -1 }
            ]
          }
          @metric = invertName

    return this

  addLimit: (limit) ->
    @threshold = limit
    return this

  getQuery: ->
    intervals = @intervals
    if not intervals
      throw new Error("must have an interval") if @forceInterval
      intervals = DruidQueryBuilder.allTimeInterval

    query = {
      queryType: @queryType
      dataSource: @dataSource
      granularity: @granularity
      intervals
    }
    query.filter = @filter if @filter
    query.dimension = @dimension if @dimension
    query.aggregations = @aggregations if @aggregations.length
    query.postAggregations = @postAggregations if @postAggregations.length
    query.metric = @metric if @metric
    query.threshold = @threshold if @threshold
    return query


druidQueryFns = {
  all: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    filter = andFilters(filter, condensedQuery.filter)

    if condensedQuery.applies.length is 0
      callback(null, [{ prop: {}, _filter: filter }])
      return

    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval)

    try
      # filter
      druidQuery.addFilter(filter)

      # apply
      if condensedQuery.applies.length
        for apply in condensedQuery.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      queryObj = druidQuery.getQuery()
    catch e
      callback(e)
      return

    requester queryObj, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if ds.length isnt 1
        callback({
          message: "unexpected result form Druid (all)"
          query: queryObj
          result: ds
        })
        return

      splits = [{
        prop: ds[0].result
        _filter: filter
      }]

      callback(null, splits)
      return
    return

  timeseries: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    filter = andFilters(filter, condensedQuery.filter)
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedQuery.split)

      # apply
      if condensedQuery.applies.length
        for apply in condensedQuery.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      queryObj = druidQuery.getQuery()
    catch e
      callback(e)
      return

    requester queryObj, (err, ds) ->
      if err
        callback(err)
        return

      # ToDo: implement actual timezones
      periodMap = {
        'PT1S': 1000
        'PT1M': 60 * 1000
        'PT1H': 60 * 60 * 1000
        'P1D' : 24 * 60 * 60 * 1000
      }

      if condensedQuery.combine?.sort?.direction is 'descending'
        ds.reverse()

      if condensedQuery.combine?.limit?
        limit = condensedQuery.combine.limit
        ds.splice(limit, ds.length - limit)

      timePropName = condensedQuery.split.name
      period = periodMap[condensedQuery.split.period]
      splits = ds.map (d) ->
        rangeStart = new Date(d.timestamp)
        range = [rangeStart, new Date(rangeStart.valueOf() + period)]
        split = {
          prop: d.result
          _filter: andFilters(filter, makeFilter(timeAttribute, range))
        }

        split.prop[timePropName] = range
        return split

      callback(null, splits)
      return
    return

  topN: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    filter = andFilters(filter, condensedQuery.filter)
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedQuery.split)

      # apply
      if condensedQuery.applies.length
        for apply in condensedQuery.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      if condensedQuery.combine
        if condensedQuery.combine.sort
          druidQuery.addSort(condensedQuery.combine.sort)

        if condensedQuery.combine.limit
          druidQuery.addLimit(condensedQuery.combine.limit)

      queryObj = druidQuery.getQuery()
    catch e
      callback(e)
      return

    requester queryObj, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if ds.length isnt 1
        callback({
          message: "unexpected result form Druid (topN)"
          query: queryObj
          result: ds
        })
        return

      filterAttribute = condensedQuery.split.attribute
      filterValueProp = condensedQuery.split.name
      splits = ds[0].result.map (prop) -> {
        prop
        _filter: andFilters(filter, makeFilter(filterAttribute, prop[filterValueProp]))
      }

      callback(null, splits)
      return
    return

  histogram: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    callback("not implemented yet"); return # ToDo
    # data.queryType = "timeseries"
    # data.postAggregations = null
    # data.aggregations = [
    #   {
    #     type: "approxHistogramFold"
    #     name: obj.dimension
    #     fieldName: obj.dimension + '_hist' # "delta_hist" ToDo: do not hard code 'hist'
    #     outputSize: obj.bucket
    #     probabilities: [0.25, 0.5, 0.75]
    #   }
    # ]
    return
}


module.exports = ({requester, dataSource, timeAttribute, approximate, filter, forceInterval}) ->
  timeAttribute or= 'time'
  approximate ?= true
  return (query, callback) ->
    condensedQuery = driverUtil.condenseQuery(query)

    rootSegment = null
    segments = [rootSegment]

    queryDruid = (condensedQuery, done) ->
      if condensedQuery.split
        switch condensedQuery.split.bucket
          when 'identity'
            if approximate
              queryFn = druidQueryFns.topN
            else
              done('not implemented yet'); return
          when 'timeDuration', 'timePeriod'
            queryFn = druidQueryFns.timeseries
          when 'continuous'
            queryFn = druidQueryFns.histogram
          else
            done('unsupported query'); return
      else
        queryFn = druidQueryFns.all

      queryForSegment = (parentSegment, done) ->
        queryFn({
          requester
          dataSource
          timeAttribute
          filter: if parentSegment then parentSegment._filter else filter
          forceInterval
          condensedQuery
        }, (err, splits) ->
          if err
            done(err)
            return
          # Make the results into segments and build the tree
          if parentSegment
            parentSegment.splits = splits
            driverUtil.cleanSegment(parentSegment)
          else
            rootSegment = splits[0]
          done(null, splits)
          return
        )
        return

      # do the query in parallel
      QUERY_LIMIT = 10
      queryFns = async.mapLimit(
        segments
        QUERY_LIMIT
        queryForSegment
        (err, results) ->
          if err
            done(err)
            return
          segments = driverUtil.flatten(results)
          done()
          return
      )
      return

    cmdIndex = 0
    async.whilst(
      -> cmdIndex < condensedQuery.length
      (done) ->
        condenced = condensedQuery[cmdIndex]
        cmdIndex++
        queryDruid(condenced, done)
        return
      (err) ->
        if err
          callback(err)
          return
        # Clean up the last segments
        segments.forEach(driverUtil.cleanSegment)

        callback(null, rootSegment)
        return
    )
    return


# -----------------------------------------------------
# Handle commonJS crap
window['druidDriver'] = exports if typeof window isnt 'undefined'
