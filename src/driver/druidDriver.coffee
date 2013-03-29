rq = (module) ->
  if typeof window is 'undefined'
    return require(module)
  else
    moduleParts = module.split('/')
    return window[moduleParts[moduleParts.length - 1]]

async = rq('async')
driverUtil = rq('./driverUtil')

if typeof exports is 'undefined'
  exports = {}

# -----------------------------------------------------

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

  constructor: (@dataSource, @timeAttribute) ->
    throw new Error("must have a dataSource") unless typeof @dataSource is 'string'
    throw new Error("must have a timeAttribute") unless typeof @timeAttribute is 'string'
    @queryType = 'timeseries'
    @granularity = 'all'
    @filter = null
    @aggregations = []
    @postAggregations = []
    @nameIndex = 0
    @intervals = DruidQueryBuilder.allTimeInterval

  dateToIntervalPart: (date) ->
    return date.toISOString()
      .replace('Z',    '') # remove Z
      .replace('.000', '') # millis if 0
      .replace(/:00$/, '') # remove seconds if 0
      .replace(/:00$/, '') # remove minutes if 0
      .replace(/T00$/, '') # remove hours if 0

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

      when 'match'
        throw new Error("can not match filter time") if filter.attribute is @timeAttribute
        [{
          type: "regex"
          dimension: filter.attribute
          pattern: filter.expression
        }]

      when 'within'
        r0 = filter.range[0]
        r1 = filter.range[1]
        if filter.attribute is @timeAttribute
          throw new Error("start and end must be dates") unless r0 instanceof Date and r1 instanceof Date
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
        throw new Error("can not apply a 'not' filter to a time interval") if i
        [{
          type: 'not'
          filed: f
        }]

      when 'and'
        fis = filter.filters.map(@filterToDruid, this)
        [
          {
            type: 'and'
            fields: fis.map((d) -> d[0])
          }
          driverUtil.flatten(fis.map((d) -> d[1]))
        ]

      when 'or'
        fis = filter.filters.map(@filterToDruid, this)
        for [f, i] in fis
          throw new Error("can not 'or' time") if i
        [{
          type: 'or'
          fields: fis.map((d) -> d[0])
        }]

      else
        throw new Error("unknown filter type '#{filter.type}'")

  addFilter: (filter) ->
    [@filter, @intervals] = @filterToDruid(filter)
    if not @intervals
      @intervals = DruidQueryBuilder.allTimeInterval
    return this

  addSplit: (split) ->
    throw new Error("split must have an attribute") unless split.attribute
    throw new Errro("split must have a name") unless split.name

    if split.attribute is @timeAttribute
      # @queryType stays 'timeseries'
      @granularity = split.duration or 'minute'
      if @granularity not in ['second', 'minute', 'hour', 'day']
        throw new Error("Unsupported duration '#{@granularity}' in time bucket")
    else
      @queryType = 'topN'
      # @granularity stays 'all'
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

  addAggregation: (agg) ->
    @aggregations.push(agg)
    return

  addPostAggregation: (postAgg) ->
    @postAggregations.push(postAgg)
    return

  addApply: (apply) ->
    throw new Error("apply must have a name") unless apply.name
    switch apply.aggregate
      when 'constant'
        @addPostAggregation {
          type: "constant"
          name: apply.name
          value: apply.value
        }

      when 'count'
        @addAggregation {
          type: "count"
          name: apply.name
        }

      when 'sum'
        @addAggregation {
          type: "doubleSum"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'average'
        @addAggregation {
          type: 'doubleSum'
          name: tempSumName = @throwawayName()
          fieldName: apply.attribute
        }

        @addAggregation {
          type: 'count'
          name: tempCountName = @throwawayName()
        }

        @addPostAggregation {
          type: "arithmetic"
          name: apply.name
          fn: "/"
          fields: [
            { type: "fieldAccess", fieldName: tempSumName }
            { type: "fieldAccess", fieldName: tempCountName }
          ]
        }

      when 'min'
        @addAggregation {
          type: "min"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'max'
        @addAggregation {
          type: "max"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'uniqueCount'
        # ToDo: add a throw here in case the user is using open source druid
        @addAggregation {
          type: "hyperUnique"
          name: apply.name
          fieldName: apply.attribute
        }

      when 'quantile'
        throw new Error("quantile apply must have quantile") unless apply.quantile
        @addAggregation {
          type: "approxHistogramFold"
          name: '_' + apply.attribute
          fieldName: apply.attribute
        }
        @addPostAggregation {
          type: "quantile"
          name: apply.name
          fieldName: '_' + apply.attribute
          probability: apply.quantile
        }

      else
        throw new Error("No supported aggregation #{apply.aggregate}")

    return this

  addSort: (sort) ->
    if sort.direction not in ['ascending', 'descending']
      throw new Error("direction has to be 'ascending' or 'descending'")

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
    query = {
      queryType: @queryType
      dataSource: @dataSource
      granularity: @granularity
      intervals: @intervals
    }
    query.filter = @filter if @filter
    query.dimension = @dimension if @dimension
    query.aggregations = @aggregations if @aggregations.length
    query.postAggregations = @postAggregations if @postAggregations.length
    query.metric = @metric if @metric
    query.threshold = @threshold if @threshold
    return query


druidQueryFns = {
  all: ({requester, dataSource, timeAttribute, filter, condensedQuery}, callback) ->
    if condensedQuery.applies.length is 0
      # Nothing to do as we are not calculating anything (not true, ToDo: fix this)
      callback(null, [{
        prop: {}
        _filter: filter
      }])
      return

    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute)

    try
      # filter
      if filter
        druidQuery.addFilter(filter)

      # apply
      for apply in condensedQuery.applies
        druidQuery.addApply(apply)
    catch e
      callback(e)
      return

    requester druidQuery.getQuery(), (err, ds) ->
      if err
        callback(err)
        return

      if ds.length isnt 1
        callback("got unexpected result from Druid")
        return

      splits = [{
        prop: ds[0].result
        _filter: filter
      }]

      callback(null, splits)
      return
    return

  timeseries: ({requester, dataSource, timeAttribute, filter, condensedQuery}, callback) ->
    if condensedQuery.applies.length is 0
      # Nothing to do as we are not calculating anything (not true, ToDo: fix this)
      callback(null, [{
        prop: {}
        _filter: filter
      }])
      return

    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute)

    try
      # split
      druidQuery.addSplit(condensedQuery.split)

      # filter
      if filter
        druidQuery.addFilter(filter)

      # apply
      for apply in condensedQuery.applies
        druidQuery.addApply(apply)
    catch e
      callback(e)
      return

    requester druidQuery.getQuery(), (err, ds) ->
      if err
        callback(err)
        return

      # ToDo: implement actual timezones
      durationMap = {
        second: 1000
        minute: 60 * 1000
        hour: 60 * 60 * 1000
        day: 24 * 60 * 60 * 1000
      }

      if condensedQuery.combine?.sort?.direction is 'descending'
        ds.reverse()

      if condensedQuery.combine?.limit?
        limit = condensedQuery.combine.limit
        ds.splice(limit, ds.length - limit)

      timePropName = condensedQuery.split.name
      duration = durationMap[condensedQuery.split.duration]
      splits = ds.map (d) ->
        rangeStart = new Date(d.timestamp)
        range = [rangeStart, new Date(rangeStart.valueOf() + duration)]
        split = {
          prop: d.result
          _filter: andFilters(filter, makeFilter(timeAttribute, range))
        }

        split.prop[timePropName] = range
        return split

      callback(null, splits)
      return
    return

  topN: ({requester, dataSource, timeAttribute, filter, condensedQuery}, callback) ->
    if condensedQuery.applies.length is 0
      # Nothing to do as we are not calculating anything (not true, ToDo: fix this)
      callback(null, [{
        prop: {}
        _filter: filter
      }])
      return

    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute)

    try
      # split
      druidQuery.addSplit(condensedQuery.split)

      # filter
      if filter
        druidQuery.addFilter(filter)

      # apply
      for apply in condensedQuery.applies
        druidQuery.addApply(apply)

      if condensedQuery.combine
        if condensedQuery.combine.sort
          druidQuery.addSort(condensedQuery.combine.sort)

        if condensedQuery.combine.limit
          druidQuery.addLimit(condensedQuery.combine.limit)
    catch e
      callback(e)
      return

    requester druidQuery.getQuery(), (err, ds) ->
      if err
        callback(err)
        return

      if ds.length isnt 1
        callback("unexpected result form Druid")
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

  histogram: ({requester, dataSource, timeAttribute, filter, condensedQuery}, callback) ->
    callback("not implemented yet"); return # ToDo
    # data.queryType = "timeseries"
    # data.postAggregations = null
    # data.aggregations = [
    #   {
    #     type: "approxHistogramFold"
    #     name: obj.dimension #"delta_hist"
    #     fieldName: obj.dimension + '_hist' # "delta_hist" ToDo: do not hard code 'hist'
    #     outputSize: obj.bucket
    #     probabilities: [0.25, 0.5, 0.75]
    #   }
    # ]
    return
}


exports = ({requester, dataSource, timeAttribute, aproximate, filter}) ->
  timeAttribute or= 'time'
  aproximate ?= true
  return (query, callback) ->
    condensedQuery = driverUtil.condenseQuery(query)

    rootSegment = null
    segments = [rootSegment]

    queryDruid = (condensedQuery, done) ->
      if condensedQuery.split
        switch condensedQuery.split.bucket
          when 'identity'
            if aproximate
              queryFn = druidQueryFns.topN
            else
              done('not implemented yet'); return
          when timeAttribute
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
if typeof module is 'undefined' then window['druidDriver'] = exports else module.exports = exports
