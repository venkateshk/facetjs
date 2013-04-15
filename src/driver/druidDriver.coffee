`(typeof window === 'undefined' ? {} : window)['druidDriver'] = (function(module, require){"use strict"; var exports = module.exports`

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
    return driverUtil.flatten(intervals) # ToDo: rewrite this to actually work

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
        throw new Error("can not fragments filter time") if filter.attribute is @timeAttribute
        [{
          type: "search"
          dimension: filter.attribute
          query: {
            type: "fragment"
            values: filter.fragments
          }
        }]

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
        druidFields = fis.map((d) -> d[0]).filter((d) -> d?)
        druidIntervals = fis.map((d) -> d[1]).filter((d) -> d?)
        druidFilter = switch druidFields.length
          when 0 then null
          when 1 then druidFields[0]
          else { type: 'and', fields: druidFields }
        [
          druidFilter
          @intersectIntervals(druidIntervals)
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
    switch split.bucket
      when 'identity'
        @queryType = 'topN'
        #@granularity stays 'all'
        @dimension = {
          type: 'default'
          dimension: split.attribute
          outputName: split.name
        }
        @threshold = 12
        @metric = null

      when 'timePeriod'
        throw new Error("timePeriod split can only work on '#{@timeAttribute}'") if split.attribute isnt @timeAttribute
        throw new Error("invalid period") unless split.period
        #@queryType stays 'timeseries'
        @granularity = {
          type: "period"
          period: split.period
          timeZone: split.timezone
        }

      when 'timeDuration'
        throw new Error("timeDuration split can only work on '#{@timeAttribute}'") if split.attribute isnt @timeAttribute
        throw new Error("invalid duration") unless split.duration
        #@queryType stays 'timeseries'
        @granularity = {
          type: "duration"
          duration: split.duration
        }

      when 'continuous'
        #@queryType stays 'timeseries'
        #@granularity stays 'all'
        tempHistogramName = @addAggregation {
          type: "approxHistogramFold"
          fieldName: split.attribute
        }

        @addPostAggregation {
          type: "buckets"
          name: "histogram"
          fieldName: tempHistogramName
          bucketSize: split.size
          offset: split.offset
        }

      when 'tuple'
        throw new Error("only supported tuples of size 2 (is: #{split.splits.length})") unless split.splits.length is 2
        @queryType = 'heatmap'
        #@granularity stays 'all'
        @dimensions = split.splits.map (split) -> {
          dimension: split.attribute
          threshold: 10 # arbitrary value to be updated later
        }

      else
        throw new Error("unsupported bucketing function")

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
    throw new Error("filtered applies are not supported yet") if apply.filter # ToDo
    @addApplyHelper(apply, false)
    return this

  addDummyApply: ->
    @addApplyHelper({ aggregate: 'count' }, false)
    return this

  addCombine: (combine) ->
    switch combine.combine
      when 'sortSlice'
        sort = combine.sort
        if sort
          if @queryType is 'topN'
            if sort.prop is @dimension.outputName
              @metric = { type: "lexicographic" }
            else
              # figure out of we need to invert and apply for a bottomN
              if sort.direction is 'descending'
                @metric = sort.prop
              else
                # make a bottomN (ToDo: is there a better way to do this?)
                @metric = @throwawayName()
                @addPostAggregation {
                  type: "arithmetic"
                  name: @metric
                  fn: "*"
                  fields: [
                    { type: "fieldAccess", fieldName: sort.prop }
                    { type: "constant", value: -1 }
                  ]
                }

        limit = combine.limit
        if limit
          @threshold = limit

      when 'matrix'
        sort = combine.sort
        if sort
          if sort.direction is 'descending'
            @metric = sort.prop
          else
            throw new Error("not supported yet")

        limits = combine.limits
        if limits
          for dim, i in @dimensions
            dim.threshold = limits[i] if limits[i]?

      else
        throw new Error("unsupported combine '#{combine.combine}'")

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
    query.dimensions = @dimensions if @dimensions
    query.aggregations = @aggregations if @aggregations.length
    query.postAggregations = @postAggregations if @postAggregations.length
    query.metric = @metric if @metric
    query.threshold = @threshold if @threshold
    return query


compareFns = {
  ascending: (a, b) ->
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

druidQueryFns = {
  all: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    filter = andFilters(filter, condensedQuery.filter)

    if condensedQuery.applies.length is 0
      callback(null, [{}])
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

      callback(null, [ds[0].result])
      return
    return

  timeseries: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
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
      callback({
        detail: e.message
      })
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

      timePropName = condensedQuery.split.name

      if condensedQuery.combine
        if condensedQuery.combine.sort
          if condensedQuery.combine.sort.prop is timePropName
            if condensedQuery.combine.sort.direction is 'descending'
              ds.reverse()
          else
            comapreFn = compareFns[condensedQuery.combine.sort.direction]
            sortProp = condensedQuery.combine.sort.prop
            ds.sort((a, b) -> comapreFn(a.result[sortProp], b.result[sortProp]))

        if condensedQuery.combine.limit?
          limit = condensedQuery.combine.limit
          driverUtil.inPlaceTrim(ds, limit)

      period = periodMap[condensedQuery.split.period]
      props = ds.map (d) ->
        rangeStart = new Date(d.timestamp)
        range = [rangeStart, new Date(rangeStart.valueOf() + period)]
        prop = d.result
        prop[timePropName] = range
        return prop

      callback(null, props)
      return
    return

  topN: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
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
        druidQuery.addCombine(condensedQuery.combine)

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

      callback(null, ds[0].result)
      return
    return

  heatmap: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
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
        druidQuery.addCombine(condensedQuery.combine)

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
          message: "unexpected result form Druid (heatmap)"
          query: queryObj
          result: ds
        })
        return

      dimensionRenameNeeded = false
      dimensionRenameMap = {}
      for split in condensedQuery.split.splits
        continue if split.name is split.attribute
        dimensionRenameMap[split.attribute] = split.name
        dimensionRenameNeeded = true

      props = ds[0].result

      if dimensionRenameNeeded
        for prop in props
          for k, v in props
            renameTo = dimensionRenameMap[k]
            if renameTo
              props[renameTo] = v
              delete props[k]

      callback(null, props)
      return
    return

  groupBy: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    callback({
      massage: 'groupBy not implemented yet (ToDo)'
    })
    return

  histogram: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedQuery}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedQuery.split)

      # applies are constrained to count
      # combine has to be computed in post processing

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
          message: "unexpected result form Druid (histogram)"
          query: queryObj
          result: ds
        })
        return

      filterAttribute = condensedQuery.split.attribute
      histName = condensedQuery.split.name
      countName = condensedQuery.applies[0].name
      { breaks, counts } = ds[0].result.histogram

      props = []
      for count, i in counts
        continue if count is 0
        range = [breaks[i], breaks[i+1]]
        prop = {}
        prop[histName] = range
        prop[countName] = count
        props.push(prop)

      if condensedQuery.combine
        if condensedQuery.combine.sort
          if condensedQuery.combine.sort.prop is histName
            if condensedQuery.combine.sort.direction is 'descending'
              props.reverse()
          else
            comapreFn = compareFns[condensedQuery.combine.sort.direction]
            sortProp = condensedQuery.combine.sort.prop
            props.sort((a, b) -> comapreFn(a[sortProp], b[sortProp]))

        if condensedQuery.combine.limit?
          limit = condensedQuery.combine.limit
          driverUtil.inPlaceTrim(props, limit)

      callback(null, props)
      return
    return
}


module.exports = ({requester, dataSource, timeAttribute, approximate, filter, forceInterval}) ->
  timeAttribute or= 'time'
  approximate ?= true
  return (query, callback) ->
    try
      condensedQuery = driverUtil.condenseQuery(query)
    catch e
      callback(e)
      return

    rootSegment = null
    segments = [rootSegment]

    queryDruid = (condensedQuery, callback) ->
      if condensedQuery.split
        switch condensedQuery.split.bucket
          when 'identity'
            if approximate
              queryFn = druidQueryFns.topN
            else
              queryFn = druidQueryFns.groupBy
          when 'timeDuration', 'timePeriod'
            queryFn = druidQueryFns.timeseries
          when 'continuous'
            queryFn = druidQueryFns.histogram
          when 'tuple'
            if approximate and condensedQuery.split.splits.length is 2
              queryFn = druidQueryFns.heatmap
            else
              queryFn = druidQueryFns.groupBy
          else
            callback('unsupported query'); return
      else
        queryFn = druidQueryFns.all

      queryForSegment = (parentSegment, callback) ->
        myFilter = andFilters((if parentSegment then parentSegment._filter else filter), condensedQuery.filter)
        queryFn({
          requester
          dataSource
          timeAttribute
          filter: myFilter
          forceInterval
          condensedQuery
        }, (err, props) ->
          if err
            callback(err)
            return

          # Make the results into segments and build the tree
          if condensedQuery.split
            splitAttribute = condensedQuery.split.attribute
            splitName = condensedQuery.split.name
            splits = props.map (prop) -> {
              prop
              _filter: andFilters(myFilter, makeFilter(splitAttribute, prop[splitName]))
            }
            parentSegment.splits = splits
            driverUtil.cleanSegment(parentSegment)
          else
            rootSegment = { prop: props[0], _filter: myFilter }
            splits = [rootSegment]

          callback(null, splits)
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
            callback(err)
            return
          segments = driverUtil.flatten(results)
          callback()
          return
      )
      return

    cmdIndex = 0
    async.whilst(
      -> cmdIndex < condensedQuery.length
      (callback) ->
        condenced = condensedQuery[cmdIndex]
        cmdIndex++
        queryDruid(condenced, callback)
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
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
