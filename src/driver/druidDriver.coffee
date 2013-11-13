`(typeof window === 'undefined' ? {} : window)['druidDriver'] = (function(module, require){"use strict"; var exports = module.exports`

async = require('async')
{ Duration } = require('./chronology')
driverUtil = require('./driverUtil')
{
  FacetQuery
  FacetFilter, TrueFilter, InFilter, AndFilter
  FacetSplit, FacetApply, FacetCombine, SliceCombine
} = require('./query')

# -----------------------------------------------------

arithmeticToDruidFn = {
  add: '+'
  subtract: '-'
  multiply: '*'
  divide: '/'
}

aggregateToJS = {
  count: ['0', (a, b) -> "#{a}+#{b}"]
  sum:   ['0', (a, b) -> "#{a}+#{b}"]
  min:   ['Infinity',  (a, b) -> "Math.min(#{a},#{b})"]
  max:   ['-Infinity', (a, b) -> "Math.max(#{a},#{b})"]
}

compareFns = {
  ascending: (a, b) ->
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

correctSingletonDruidResult = (result) ->
  return Array.isArray(result) and result.length <= 1 and (result.length is 0 or result[0].result)

emptySingletonDruidResult = (result) ->
  return result.length is 0

class DruidQueryBuilder
  @ALL_DATA_CHUNKS = 10000
  @allTimeInterval = ["1000-01-01/3000-01-01"]

  @dateToIntervalPart = (date) ->
    return date.toISOString()
      .replace('Z',    '') # remove Z
      .replace('.000', '') # millis if 0
      .replace(/:00$/, '') # remove seconds if 0
      .replace(/:00$/, '') # remove minutes if 0
      .replace(/T00$/, '') # remove hours if 0

  constructor: ({@dataSource, @timeAttribute, @forceInterval, @approximate, @priority}) ->
    throw new Error("must have a dataSource") unless typeof @dataSource is 'string'
    throw new Error("must have a timeAttribute") unless typeof @timeAttribute is 'string'
    @priority ?= 'default'
    throw new TypeError("invalid priority") if @priority isnt 'default' and isNaN(@priority)
    @queryType = 'timeseries'
    @granularity = 'all'
    @filter = null
    @aggregations = []
    @postAggregations = []
    @nameIndex = 0
    @intervals = null
    @useCache = true

  addToContext: (context, attribute) ->
    return context[attribute] if context[attribute]
    context[attribute] = "v#{@jsCount}"
    @jsCount++
    return context[attribute]

  # return { jsFilter, context }
  filterToJSHelper: (filter, context) ->
    switch filter.type
      when 'true', 'false' then filter.type

      when 'is'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        varName = @addToContext(context, filter.attribute)
        "#{varName}==='#{filter.value}'"

      when 'in'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        varName = @addToContext(context, filter.attribute)
        filter.values.map((value) -> "#{varName}==='#{value}'").join('||')

      when 'contains'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        varName = @addToContext(context, filter.attribute)
        "#{varName}.indexOf('#{filter.value}') !== -1"

      when 'not'
        "!(#{@filterToJSHelper(filter.filter, context)})"

      when 'and'
        filter.filters.map(((filter) -> "(#{@filterToJSHelper(filter, context)})"), this).join('&&')

      when 'or'
        filter.filters.map(((filter) -> "(#{@filterToJSHelper(filter, context)})"), this).join('||')

      else
        throw new Error("unknown JS filter type '#{filter.type}'")

  filterToJS: (filter) ->
    context = {}
    @jsCount = 0
    jsFilter = @filterToJSHelper(filter, context)
    return {
      jsFilter
      context
    }

  timelessFilterToDruid: (filter) ->
    switch filter.type
      when 'true'
        null

      when 'false'
        throw new Error("should never get here")

      when 'is'
        {
          type: 'selector'
          dimension: filter.attribute
          value: filter.value ? '' # In Druid null == '' and null is illegal
        }

      when 'in'
        {
          type: 'or'
          fields: filter.values.map(((value) ->
            return {
              type: 'selector'
              dimension: filter.attribute
              value: value ? '' # In Druid null == '' and null is illegal
            }
          ), this)
        }

      when 'contains'
        {
          type: "search"
          dimension: filter.attribute
          query: {
            type: "fragment"
            values: [filter.value]
          }
        }

      when 'match'
        {
          type: "regex"
          dimension: filter.attribute
          pattern: filter.expression
        }

      when 'within'
        [r0, r1] = filter.range
        if typeof r0 is 'number' and typeof r1 is 'number'
          {
            type: 'javascript'
            dimension: filter.attribute
            function: "function(a){return a=~~a,#{r0}<=a&&a<#{r1};}"
          }
        else
          throw new Error("apply within has to have a numeric range")

      when 'not'
        {
          type: 'not'
          field: @timelessFilterToDruid(filter.filter)
        }

      when 'and', 'or'
        {
          type: filter.type
          fields: filter.filters.map(@timelessFilterToDruid, this)
        }

      else
        throw new Error("filter type '#{filter.type}' not defined")

  timeFilterToDruid: (filter) ->
    return null unless filter
    ors = if filter.type is 'or' then filter.filters else [filter]
    timeAttribute = @timeAttribute
    return ors.map ({type, attribute, range}) ->
      throw new Error("can only time filter with a 'within' filter") unless type is 'within'
      throw new Error("attribute has to be a time attribute") unless attribute is timeAttribute
      return "#{DruidQueryBuilder.dateToIntervalPart(range[0])}/#{DruidQueryBuilder.dateToIntervalPart(range[1])}"


  addFilter: (filter) ->
    dateToIntervalPart = DruidQueryBuilder.dateToIntervalPart
    return unless filter
    extract = filter.extractFilterByAttribute(@timeAttribute)
    throw new Error("could not separate time filter") unless extract
    [timelessFilter, timeFilter] = extract

    if timelessFilter.type is 'false'
      @filter = null
      @intervals = ["9001-01-01/9001-01-02"] # over 9000!
    else
      @filter = @timelessFilterToDruid(timelessFilter)
      @intervals = @timeFilterToDruid(timeFilter)

    return this


  addSplit: (split) ->
    throw new TypeError() unless split instanceof FacetSplit
    switch split.bucket
      when 'identity'
        @queryType = 'groupBy'
        #@granularity stays 'all'
        @dimension = {
          type: 'default'
          dimension: split.attribute
          outputName: split.name
        }

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
        throw new Error("approximate queries not allowed") unless @approximate
        #@queryType stays 'timeseries'
        #@granularity stays 'all'
        aggregation = {
          type: "approxHistogramFold"
          fieldName: split.attribute
        }
        aggregation.lowerLimit = split.lowerLimit if split.lowerLimit?
        aggregation.upperLimit = split.upperLimit if split.upperLimit?
        options = split.options or {}
        aggregation.resolution = options.druidResolution if options.druidResolution
        tempHistogramName = @addAggregation(aggregation)
        @addPostAggregation {
          type: "buckets"
          name: "histogram"
          fieldName: tempHistogramName
          bucketSize: split.size
          offset: split.offset
        }
        #@useCache = false

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
      when 'fieldAccess', 'hyperUniqueCardinality', 'quantile'
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
         String(existingAggregation.fieldNames) is String(aggregation.fieldNames) and
         existingAggregation.fnAggregate is aggregation.fnAggregate and
         existingAggregation.fnCombine is aggregation.fnCombine and
         existingAggregation.fnReset is aggregation.fnReset and
         existingAggregation.resolution is aggregation.resolution and
         existingAggregation.lowerLimit is aggregation.lowerLimit and
         existingAggregation.upperLimit is aggregation.upperLimit and
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
  addApplyHelper: (apply, returnPostAggregation) ->
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
          if @approximate and apply.aggregate in ['min', 'max'] and /_hist$/.test(apply.attribute)
            # A hacky way to determine that this is a histogram aggregated column (it ends with _hist)

            aggregation = {
              type: "approxHistogramFold"
              fieldName: apply.attribute
            }
            options = apply.options or {}
            aggregation.lowerLimit = options.druidLowerLimit if options.druidLowerLimit?
            aggregation.upperLimit = options.druidUpperLimit if options.druidUpperLimit?
            aggregation.resolution = options.druidResolution if options.druidResolution
            histogramAggregationName = @addAggregation(aggregation)
            postAggregation = {
              type: apply.aggregate
              fieldName: histogramAggregationName
            }

            if returnPostAggregation
              return postAggregation
            else
              postAggregation.name = applyName
              @addPostAggregation(postAggregation)
              return
          else
            if apply.filter
              { jsFilter, context } = @filterToJS(apply.filter)
              fieldNames = []
              varNames = []
              for fieldName, varName of context
                fieldNames.push(fieldName)
                varNames.push(varName)

              [zero, jsAgg] = aggregateToJS[apply.aggregate]

              if apply.aggregate is 'count'
                jsIf = "(#{jsFilter}?1:#{zero})"
              else
                fieldNames.push(apply.attribute)
                varNames.push('a')
                jsIf = "(#{jsFilter}?a:#{zero})"

              aggregation = {
                type: "javascript"
                name: applyName
                fieldNames: fieldNames
                fnAggregate: "function(cur,#{varNames.join(',')}){return #{jsAgg('cur', jsIf)};}"
                fnCombine: "function(pa,pb){return #{jsAgg('pa', 'pb')};}"
                fnReset: "function(){return #{zero};}"
              }
            else
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
          throw new Error("approximate queries not allowed") unless @approximate
          throw new Error("filtering uniqueCount unsupported by driver") if apply.filter

          # ToDo: add a throw here in case approximate is false
          aggregation = {
            type: "hyperUnique"
            name: applyName
            fieldName: apply.attribute
          }

          aggregationName = @addAggregation(aggregation)
          if returnPostAggregation
            # hyperUniqueCardinality is the fieldAccess equivalent for uniques
            return { type: "hyperUniqueCardinality", fieldName: aggregationName }
          else
            return

        when 'average'
          throw new Error("can not filter an average right now") if apply.filter

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
          throw new Error("approximate queries not allowed") unless @approximate
          throw new Error("quantile apply must have quantile") unless apply.quantile
          aggregation = {
            type: "approxHistogramFold"
            fieldName: apply.attribute
          }
          options = apply.options or {}
          aggregation.lowerLimit = options.druidLowerLimit if options.druidLowerLimit?
          aggregation.upperLimit = options.druidUpperLimit if options.druidUpperLimit?
          aggregation.resolution = options.druidResolution if options.druidResolution
          histogramAggregationName = @addAggregation(aggregation)
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
      if apply.operands.length isnt 2
        throw new Error("arithmetic apply must have 2 operands (has: #{apply.operands.length})")
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
    throw new TypeError() unless apply instanceof FacetApply
    @addApplyHelper(apply, false)
    return this

  addDummyApply: ->
    @addApplyHelper({ aggregate: 'count' }, false)
    return this

  addCombine: (combine) ->
    throw new TypeError() unless combine instanceof FacetCombine
    switch combine.method
      when 'slice'
        { sort, limit } = combine

        if @queryType is 'groupBy'
          if sort and limit?
            throw new Error("can not sort and limit on without approximate") unless @approximate
            @queryType = 'topN'
            @threshold = limit
            if sort.prop is @dimension.outputName
              if sort.direction is 'ascending'
                @metric = { type: "lexicographic" }
              else
                @metric = { type: "inverted", metric: { type: "lexicographic" } }
            else
              if sort.direction is 'descending'
                @metric = sort.prop
              else
                @metric = { type: "inverted", metric: sort.prop }

          else if sort
            # groupBy can only sort lexicographic
            throw new Error("can not do an unlimited sort on an apply") unless sort.prop is @dimension.outputName

          else if limit?
            throw new Error("handle this better")

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
        throw new Error("unsupported method '#{combine.method}'")

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

    if not @useCache
      query.context or= {}
      query.context.useCache = false
      query.context.populateCache = false

    if @priority isnt 'default'
      query.context or= {}
      query.context.priority = @priority

    query.filter = @filter if @filter

    if @dimension
      if @queryType is 'groupBy'
        query.dimensions = [@dimension]
      else
        query.dimension = @dimension
    else if @dimensions
      query.dimensions = @dimensions

    query.aggregations = @aggregations if @aggregations.length
    query.postAggregations = @postAggregations if @postAggregations.length
    query.metric = @metric if @metric
    query.threshold = @threshold if @threshold
    return query

DruidQueryBuilder.queryFns = {
  all: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      # filter
      queryBuilder.addFilter(filter)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if not correctSingletonDruidResult(ds)
        callback({
          message: "unexpected result from Druid (all)"
          query: queryObj
          result: ds
        })
        return

      callback(null, if emptySingletonDruidResult(ds) then null else ds.map((d) -> d.result))
      return
    return

  timeBoundry: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    if not condensedCommand.applies.every((apply) -> apply.attribute is queryBuilder.timeAttribute and apply.aggregate in ['min', 'max'])
      callback(new Error("can not mix and match min / max time with other aggregates (for now)"))
      return

    queryObj = {
      queryType: "timeBoundary"
      dataSource: queryBuilder.dataSource
    }

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if not correctSingletonDruidResult(ds) or ds.length isnt 1
        callback({
          message: "unexpected result from Druid (timeBoundry)"
          query: queryObj
          result: ds
        })
        return

      prop = {}
      for {name, aggregate} in condensedCommand.applies
        prop[name] = new Date(ds[0].result[aggregate + 'Time'])

      callback(null, [prop])
      return

    return

  timeseries: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      # ToDo: implement actual timezones
      canonicalPeriodMap = {
        'PT1S': 1000
        'PT1M': 60 * 1000
        'PT1H': 60 * 60 * 1000
        'P1D' : 24 * 60 * 60 * 1000
      }

      timePropName = condensedCommand.split.name

      timezone = condensedCommand.split.timezone or 'Etc/UTC'
      splitDuration = new Duration(condensedCommand.split.period)
      canonicalPeriod = canonicalPeriodMap[condensedCommand.split.period]
      canonicalPeriodAndThenSome = canonicalPeriod * 1.5
      props = ds.map (d, i) ->
        rangeStart = new Date(d.timestamp)
        next = ds[i + 1]
        next = new Date(next.timestamp) if next

        if next and rangeStart < next and next - rangeStart < canonicalPeriodAndThenSome
          rangeEnd = next
        else
          rangeEnd = splitDuration.move(rangeStart, timezone, 1)

        prop = d.result
        prop[timePropName] = [rangeStart, rangeEnd]
        return prop

      if condensedCommand.combine
        if condensedCommand.combine.sort
          if condensedCommand.combine.sort.prop is timePropName
            if condensedCommand.combine.sort.direction is 'descending'
              props.reverse()
          else
            comapreFn = compareFns[condensedCommand.combine.sort.direction]
            sortProp = condensedCommand.combine.sort.prop
            props.sort((a, b) -> comapreFn(a[sortProp], b[sortProp]))

        if condensedCommand.combine.limit?
          limit = condensedCommand.combine.limit
          driverUtil.inPlaceTrim(props, limit)

      callback(null, if props.length then props else null)
      return
    return

  topN: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      if condensedCommand.combine
        queryBuilder.addCombine(condensedCommand.combine)

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if not correctSingletonDruidResult(ds)
        callback({
          message: "unexpected result from Druid (topN)"
          query: queryObj
          result: ds
        })
        return

      callback(null, if emptySingletonDruidResult(ds) then null else ds[0].result)
      return
    return

  allData: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    allDataChunks = DruidQueryBuilder.ALL_DATA_CHUNKS

    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      queryBuilder.addCombine(new SliceCombine({
        sort: {
          compare: 'natural'
          prop: condensedCommand.split.name
          direction: condensedCommand.combine?.sort.direction or 'ascending'
        }
        limit: allDataChunks
      }))

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    props = []
    done = false
    queryObj.metric.previousStop = null
    async.whilst(
      -> not done
      (callback) ->
        requester {query: queryObj}, (err, ds) ->
          if err
            callback(err)
            return

          if not correctSingletonDruidResult(ds)
            callback({
              message: "unexpected result from Druid (topN/allData)"
              query: queryObj
              result: ds
            })
            return

          myProps = if emptySingletonDruidResult(ds) then [] else ds[0].result
          props = props.concat(myProps)
          if myProps.length < allDataChunks
            done = true
          else
            queryObj.metric.previousStop = myProps[allDataChunks - 1][condensedCommand.split.name]
          callback()
        return
      (err) ->
        if err
          callback(err)
          return

        callback(null, if props.length then props else null)
        return
    )
    return

  groupBy: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      if condensedCommand.combine
        queryBuilder.addCombine(condensedCommand.combine)

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    # console.log '------------------------------'
    # console.log queryObj

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      # console.log '------------------------------'
      # console.log err, ds

      callback(null, ds.map((d) -> d.event))
      return
    return

  histogram: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    if not condensedCommand.applies.every(({aggregate}) -> aggregate is 'count')
      callback(new Error("only count aggregated applies are supported"))
      return

    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # applies are constrained to count
      # combine has to be computed in post processing

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if not correctSingletonDruidResult(ds)
        callback({
          message: "unexpected result from Druid (histogram)"
          query: queryObj
          result: ds
        })
        return

      if emptySingletonDruidResult(ds)
        callback(null, null)
        return

      if not ds[0].result or not ds[0].result.histogram
        callback(new Error('invalid histogram result'), null)
        return

      { breaks, counts } = ds[0].result.histogram
      filterAttribute = condensedCommand.split.attribute
      histName = condensedCommand.split.name
      countName = condensedCommand.applies[0].name

      props = []
      for count, i in counts
        continue if count is 0
        range = [breaks[i], breaks[i + 1]]
        prop = {}
        prop[histName] = range
        prop[countName] = count
        props.push(prop)

      if condensedCommand.combine
        if condensedCommand.combine.sort
          if condensedCommand.combine.sort.prop is histName
            if condensedCommand.combine.sort.direction is 'descending'
              props.reverse()
          else
            comapreFn = compareFns[condensedCommand.combine.sort.direction]
            sortProp = condensedCommand.combine.sort.prop
            props.sort((a, b) -> comapreFn(a[sortProp], b[sortProp]))

        if condensedCommand.combine.limit?
          limit = condensedCommand.combine.limit
          driverUtil.inPlaceTrim(props, limit)

      callback(null, props)
      return
    return

  heatmap: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      # filter
      queryBuilder.addFilter(filter)

      # split
      queryBuilder.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          queryBuilder.addApply(apply)
      else
        queryBuilder.addDummyApply()

      if condensedCommand.combine
        queryBuilder.addCombine(condensedCommand.combine)

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback({
          message: err
          query: queryObj
        })
        return

      if not correctSingletonDruidResult(ds)
        callback({
          message: "unexpected result from Druid (heatmap)"
          query: queryObj
          result: ds
        })
        return

      if emptySingletonDruidResult(ds)
        callback(null, null)
        return

      dimensionRenameNeeded = false
      dimensionRenameMap = {}
      for split in condensedCommand.split.splits
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
}

DruidQueryBuilder.makeSingleQuery = ({parentSegment, filter, condensedCommand, builderSettings, requester}, callback) ->
  { timeAttribute, approximate } = builderSettings
  if condensedCommand.split
    switch condensedCommand.split.bucket
      when 'identity'
        if approximate
          if condensedCommand.combine?.limit?
            queryFnName = 'topN'
          else
            queryFnName = 'allData'
        else
          queryFnName = 'groupBy'
      when 'timeDuration', 'timePeriod'
        queryFnName = 'timeseries'
      when 'continuous'
        queryFnName = 'histogram'
      when 'tuple'
        if approximate and condensedCommand.split.splits.length is 2
          queryFnName = 'heatmap'
        else
          queryFnName = 'groupBy'
      else
        callback({ message: 'unsupported split bucket' }); return
  else
    if condensedCommand.applies.some((apply) -> apply.attribute is timeAttribute and apply.aggregate in ['min', 'max'])
      queryFnName = 'timeBoundry'
    else
      queryFnName = 'all'

  queryFn = DruidQueryBuilder.queryFns[queryFnName]

  queryFn({
    requester
    queryBuilder: new DruidQueryBuilder(builderSettings)
    filter
    parentSegment
    condensedCommand
  }, callback)
  return


addSplitName = (split, name) ->
  splitSpec = split.valueOf()
  splitSpec.name = name
  return FacetSplit.fromSpec(splitSpec)

addApplyName = (apply, name) ->
  applySpec = apply.valueOf()
  applySpec.name = name
  return FacetApply.fromSpec(applySpec)


class ApplySegregator
  constructor: ->
    @byDataset = {}
    @postProcess = []
    @nameIndex = 0

  getNextName: ->
    @nameIndex++
    return "_N_" + @nameIndex

  addSingleDatasetApply: (apply, track) ->
    if apply.aggregate is 'constant'
      value = apply.value
      return -> value

    dataset = apply.getDataset()
    apply = addApplyName(apply, @getNextName()) if not apply.name
    @byDataset[dataset] or= []

    existingApplyGetter = driverUtil.find(@byDataset[dataset], (ag) -> ag.apply.isEqual(apply))

    if not existingApplyGetter
      name = apply.name
      getter = (prop) -> prop[name]
      @byDataset[dataset].push(existingApplyGetter = { apply, getter })

    if track
      @trackApplySegmentation.push({ dataset, applyName: existingApplyGetter.apply.name })

    return existingApplyGetter.getter

  addMultiDatasetApply: (apply, track) ->
    [op1, op2] = apply.operands
    op1Datasets = op1.getDatasets()
    op2Datasets = op2.getDatasets()
    getter1 = if op1Datasets.length <= 1 then @addSingleDatasetApply(op1, track) else @addMultiDatasetApply(op1, track)
    getter2 = if op2Datasets.length <= 1 then @addSingleDatasetApply(op2, track) else @addMultiDatasetApply(op2, track)
    combineFn = ApplySegregator.arithmeticToCombineFn[apply.arithmetic]
    return (prop) -> combineFn(getter1(prop), getter2(prop))

  addApplies: (applies, trackApplyName) ->
    @trackApplySegmentation = []

    # First add all the simple applies then add the multi-dataset applies
    # This greatly simplifies the logic in the addSingleDatasetApply function because it never have to
    # substitute an apply with a temp name with one that has a permanent name

    multiDatasetApplies = []
    for apply in applies
      if apply.getDatasets().length <= 1
        @addSingleDatasetApply(apply, apply.name is trackApplyName)
      else
        multiDatasetApplies.push(apply)

    multiDatasetApplies.forEach(((apply) ->
      name = apply.name
      getter = @addMultiDatasetApply(apply, name is trackApplyName)
      @postProcess.push (prop) ->
        prop[name] = getter(prop)
        return
    ), this)

    return @trackApplySegmentation

  getAppliesForDataset: (dataset) ->
    return (@byDataset[dataset] or []).map((d) -> d.apply)

  getPostProcessors: ->
    return @postProcess


ApplySegregator.arithmeticToCombineFn = {
  add:      (lhs, rhs) -> lhs + rhs
  subtract: (lhs, rhs) -> lhs - rhs
  multiply: (lhs, rhs) -> lhs * rhs
  divide:   (lhs, rhs) -> if rhs is 0 then 0 else lhs / rhs
}


# Split up the condensed command into condensed commands contained within the dataset
splitupCondensedCommand = (condensedCommand) ->
  datasets = condensedCommand.getDatasets()
  tempProps = []
  perDatasetInfo = []
  if datasets.length <= 1
    if datasets.length
      perDatasetInfo.push {
        dataset: datasets[0]
        condensedCommand
      }

    return {
      postProcessors: []
      perDatasetInfo
    }

  # Separate splits
  for dataset in datasets
    datasetSplie = null
    if condensedCommand.split
      splitName = condensedCommand.split.name
      for subSplit in condensedCommand.split.splits
        continue unless subSplit.getDataset() is dataset
        datasetSplit = addSplitName(subSplit, splitName)
        break

    perDatasetInfo.push {
      dataset
      condensedCommand: {
        split: datasetSplit
        applies: []
        combine: null
      }
    }

  # Separate applies
  applySegregator = new ApplySegregator()
  sortApplySegmentation = applySegregator.addApplies(condensedCommand.applies, condensedCommand.combine?.sort?.prop)

  for info in perDatasetInfo
    info.condensedCommand.applies = applySegregator.getAppliesForDataset(info.dataset)

  # Setup combines
  if condensedCommand.combine
    sort = condensedCommand.combine.sort
    if sort
      splitName = condensedCommand.split.name
      if sortApplySegmentation.length is 0
        # Sorting on splitting prop
        for info in perDatasetInfo
          info.condensedCommand.combine = condensedCommand.combine
      else if sortApplySegmentation.length is 1
        # Sorting on regular apply
        mainDataset = sortApplySegmentation[0].dataset

        for info in perDatasetInfo
          if info.dataset is mainDataset
            info.condensedCommand.combine = condensedCommand.combine
          else
            info.driven = true
            info.condensedCommand.combine = new SliceCombine({
              sort: {
                compare: 'natural'
                direction: 'descending'
                prop: splitName
              }
              limit: condensedCommand.combine.limit
            })
      else
        # Sorting on a post apply
        for info in perDatasetInfo
          infoApplyName = driverUtil.find(sortApplySegmentation, ({dataset}) -> dataset is info.dataset)
          if infoApplyName
            # has a part of the apply that will be combined into the sorting apply
            sortProp = infoApplyName.applyName
          else
            sortProp = splitName
            info.driven = true

          info.condensedCommand.combine = new SliceCombine({
            sort: {
              compare: 'natural'
              direction: 'descending'
              prop: sortProp
            }
            limit: 1000
          })

    else
      # no sort... do not do anything for now
      null
  else
    # no combine... so do not add one
    null

  return {
    postProcessors: applySegregator.getPostProcessors()
    perDatasetInfo
  }


# Make a multi-dataset query
multiDatasetQuery = ({parentSegment, condensedCommand, builderSettings, requester}, callback) ->
  datasets = condensedCommand.getDatasets()
  if datasets.length is 0
    # If there are no datasets it means that this is a 'no-op' query, it has no splits or applies
    callback(null, [{}])
    return

  if datasets.length is 1
    # If there is only one dataset just make the single query (shortcut)
    DruidQueryBuilder.makeSingleQuery({
      parentSegment
      filter: parentSegment._filtersByDataset[datasets[0]]
      condensedCommand: condensedCommand
      builderSettings
      requester
    }, callback)
    return

  { postProcessors, perDatasetInfo } = splitupCondensedCommand(condensedCommand)

  performApplyCombine = (result) ->
    for postProcessor in postProcessors
      result.forEach(postProcessor)

    if condensedCommand.combine
      combine = condensedCommand.combine
      if combine.sort
        compareFn = combine.sort.getCompareFn()
        result.sort(compareFn)

      if combine.limit?
        driverUtil.inPlaceTrim(result, combine.limit)
    return

  hasDriven = false
  allApplyNames = []
  for info in perDatasetInfo
    hasDriven or= info.driven
    allApplyNames.push(apply.name) for apply in info.condensedCommand.applies

  driverQueries = driverUtil.filterMap perDatasetInfo, (info) ->
    return if info.driven
    return (callback) ->
      DruidQueryBuilder.makeSingleQuery({
        parentSegment
        filter: parentSegment._filtersByDataset[info.dataset]
        condensedCommand: info.condensedCommand
        builderSettings
        requester
      }, callback)

  async.parallel driverQueries, (err, driverResults) ->
    if err
      callback(err)
      return

    driverResult = driverUtil.joinResults(
      if condensedCommand.split then [condensedCommand.split.name] else []
      allApplyNames
      driverResults
    )

    if hasDriven and condensedCommand.split
      # make filter
      splitName = condensedCommand.split.name

      drivenQueries = driverUtil.filterMap perDatasetInfo, (info) ->
        return unless info.driven

        throw new Error("This (#{condensedCommand.split.bucket}) split not implemented yet") unless info.condensedCommand.split.bucket is 'identity'
        driverFilter = new InFilter({
          attribute: info.condensedCommand.split.attribute
          values: driverResult.map((prop) -> prop[splitName])
        })

        return (callback) ->
          DruidQueryBuilder.makeSingleQuery({
            parentSegment
            filter: new AndFilter([parentSegment._filtersByDataset[info.dataset], driverFilter])
            condensedCommand: info.condensedCommand
            builderSettings
            requester
          }, callback)

      async.parallel drivenQueries, (err, drivenResults) ->
        fullResult = driverUtil.joinResults(
          [condensedCommand.split.name]
          allApplyNames
          [driverResult].concat(drivenResults)
        )
        performApplyCombine(fullResult)
        callback(null, fullResult)
        return
    else
      performApplyCombine(driverResult)
      # console.log driverResults
      # console.log '-----------------------'
      # console.log driverResult
      callback(null, driverResult)
    return

  return


# This is the Druid driver. It translates facet queries to Druid
#
# @param {Requester} requester, a function to make requests to Druid
# @param {string} dataSource, name of the datasource in Druid
# @param {string} timeAttribute [optional, default="time"], name by which the time attribute will be referred to
# @param {boolean} approximate [optional, default=false], allow use of approximate queries
# @param {Filter} filter [optional, default=null], the filter that should be applied to the data
# @param {boolean} forceInterval [optional, default=false], if true will not execute queries without a time constraint
# @param {number} concurrentQueryLimit [optional, default=16], max number of queries to execute concurrently
# @param {number} queryLimit [optional, default=Infinity], max query complexity
#
# @return {FacetDriver} the driver that does the requests

module.exports = ({requester, dataSource, timeAttribute, approximate, filter, forceInterval, concurrentQueryLimit, queryLimit}) ->
  throw new Error("must have a requester") unless typeof requester is 'function'
  timeAttribute or= 'time'
  approximate ?= true
  concurrentQueryLimit or= 16
  queryLimit or= Infinity
  filter ?= new TrueFilter()
  throw new TypeError("filter should be a FacetFilter") unless filter instanceof FacetFilter

  queriesMade = 0
  return (request, callback) ->
    try
      throw new Error("request not supplied") unless request
      {context, query} = request
      throw new Error("query not supplied") unless query
      throw new TypeError("query must be a FacetQuery") unless query instanceof FacetQuery
      context or= {}
    catch e
      callback(e)
      return

    commonFilter = new AndFilter([filter, query.getFilter()])
    filtersByDataset = {}
    for dataset in query.getDatasets()
      filtersByDataset[dataset] = new AndFilter([commonFilter, query.getDatasetFilter(dataset)]).simplify()

    init = true
    rootSegment = {
      parent: null
      _filtersByDataset: filtersByDataset
    }
    segments = [rootSegment]

    condensedGroups = query.getGroups()

    queryDruid = (condensedCommand, lastCmd, callback) ->
      if condensedCommand.split?.segmentFilter
        segmentFilterFn = condensedCommand.split.segmentFilter.getFilterFn()
        driverUtil.inPlaceFilter(segments, segmentFilterFn)

      # do the query in parallel
      async.mapLimit(
        segments
        concurrentQueryLimit
        (parentSegment, callback) ->
          queriesMade++
          if queryLimit < queriesMade
            callback({ message: 'query limit exceeded' })
            return

          multiDatasetQuery({
            requester
            builderSettings: {
              dataSource
              timeAttribute
              forceInterval
              approximate
              priority: context.priority
            }
            parentSegment
            condensedCommand
          }, (err, props) ->
            if err
              callback(err)
              return

            if props is null
              callback(null, null)
              return

            # Make the results into segments and build the tree
            if condensedCommand.split
              propToSplit = if lastCmd
                (prop) ->
                  driverUtil.cleanProp(prop)
                  return {
                    parent: parentSegment
                    prop
                  }
              else
                (prop) ->
                  driverUtil.cleanProp(prop)
                  return {
                    parent: parentSegment
                    prop
                    _filtersByDataset: FacetFilter.andFiltersByDataset(
                      parentSegment._filtersByDataset
                      condensedCommand.split.getFilterByDatasetFor(prop)
                    )
                  }

              parentSegment.splits = splits = props.map(propToSplit)
            else
              prop = props[0]
              driverUtil.cleanProp(prop)
              splits = [{
                parent: parentSegment
                prop
                _filtersByDataset: parentSegment._filtersByDataset
              }]

            callback(null, splits)
            return
          )
          return
        (err, results) ->
          if err
            callback(err)
            return

          if results.some((result) -> result is null)
            rootSegment = null
          else
            segments = driverUtil.flatten(results)
            if init
              rootSegment = segments[0]
              init = false

          callback()
          return
      )
      return

    cmdIndex = 0
    async.whilst(
      -> cmdIndex < condensedGroups.length and rootSegment
      (callback) ->
        condensedGroup = condensedGroups[cmdIndex]
        cmdIndex++
        last = cmdIndex is condensedGroups.length
        queryDruid(condensedGroup, last, callback)
        return
      (err) ->
        if err
          callback(err)
          return

        callback(null, driverUtil.cleanSegments(rootSegment or {}))
        return
    )
    return

module.exports.DruidQueryBuilder = DruidQueryBuilder

# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath, altPath) {
    if (altPath) return window[altPath];
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
