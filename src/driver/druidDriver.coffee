`(typeof window === 'undefined' ? {} : window)['druidDriver'] = (function(module, require){"use strict"; var exports = module.exports`

async = require('async')
driverUtil = require('./driverUtil')
{FacetFilter, TrueFilter, FacetSplit, FacetApply, FacetCombine, FacetQuery, AndFilter} = require('./query')

# -----------------------------------------------------

andFilters = (filter1, filter2) ->
  return new AndFilter([filter1, filter2]).simplify()

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

  constructor: (@dataSource, @timeAttribute, @forceInterval, @approximate, @priority) ->
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
          throw new Error("has to be a numeric range")

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
  addApplyHelper: do ->
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
            if @approximate and apply.aggregate in ['min', 'max'] and /_hist$/.test(apply.attribute)
              # A hacky way to determine that this is a histogram aggregated column (it ends with _hist)

              aggregation = {
                type: "approxHistogramFold"
                fieldName: apply.attribute
              }
              options = apply.options or {}
              aggregation.lowerLimit = options.druidLowerLimit if options.druidLowerLimit?
              aggregation.lowerUpper = options.druidLowerUpper if options.druidLowerUpper?
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
            aggregation.lowerUpper = options.druidLowerUpper if options.druidLowerUpper?
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
    @addApplyHelper(apply, false)
    return this

  addDummyApply: ->
    @addApplyHelper({ aggregate: 'count' }, false)
    return this

  addCombine: (combine) ->
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


compareFns = {
  ascending: (a, b) ->
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

correctSingletonDruidResult = (result) ->
  return Array.isArray(result) and result.length <= 1 and (result.length is 0 or result[0].result)

emptySingletonDruidResult = (result) ->
  return result.length is 0 or result[0].result.length is 0

druidQueryFns = {
  all: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    if condensedCommand.applies.length is 0
      callback(null, [{}])
      return

    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
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

  timeseries: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
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

      timePropName = condensedCommand.split.name

      if condensedCommand.combine
        if condensedCommand.combine.sort
          if condensedCommand.combine.sort.prop is timePropName
            if condensedCommand.combine.sort.direction is 'descending'
              ds.reverse()
          else
            comapreFn = compareFns[condensedCommand.combine.sort.direction]
            sortProp = condensedCommand.combine.sort.prop
            ds.sort((a, b) -> comapreFn(a.result[sortProp], b.result[sortProp]))

        if condensedCommand.combine.limit?
          limit = condensedCommand.combine.limit
          driverUtil.inPlaceTrim(ds, limit)

      period = periodMap[condensedCommand.split.period]
      props = ds.map (d) ->
        rangeStart = new Date(d.timestamp)
        range = [rangeStart, new Date(rangeStart.valueOf() + period)]
        prop = d.result
        prop[timePropName] = range
        return prop

      # Total Hack!
      # Trim down the 0s from the end in an ascending timeseries
      # Remove this when druid pushes the new code live.
      interestingApplies = condensedCommand.applies.filter ({aggregate}) -> aggregate not in ['min', 'max']
      if condensedCommand.combine.sort.direction is 'ascending' and interestingApplies.length
        while props.length
          lastProp = props[props.length - 1]
          allZero = true
          for apply in interestingApplies
            allZero = allZero and lastProp[apply.name] is 0
          if allZero
            props.pop()
          else
            break
      #/ Hack

      callback(null, if props.length then props else null)
      return
    return

  topN: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      if condensedCommand.combine
        druidQuery.addCombine(condensedCommand.combine)

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

  allData: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)
    allDataChunks = DruidQueryBuilder.ALL_DATA_CHUNKS

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      druidQuery.addCombine({
        combine: 'slice'
        sort: {
          compare: 'natural'
          prop: condensedCommand.split.name
          direction: condensedCommand.combine.sort.direction
        }
        limit: allDataChunks
      })

      queryObj = druidQuery.getQuery()
    catch e
      callback(e)
      return

    props = []
    done = false
    queryObj.metric.previousStop = null
    async.whilst(
      -> not done
      (callback) ->
        requester queryObj, (err, ds) ->
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

  groupBy: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      if condensedCommand.combine
        druidQuery.addCombine(condensedCommand.combine)

      queryObj = druidQuery.getQuery()
    catch e
      callback(e)
      return

    # console.log '------------------------------'
    # console.log queryObj

    requester queryObj, (err, ds) ->
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

  histogram: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

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

      { breaks, counts } = ds[0].result.histogram
      filterAttribute = condensedCommand.split.attribute
      histName = condensedCommand.split.name
      countName = condensedCommand.applies[0].name

      props = []
      for count, i in counts
        continue if count is 0
        range = [breaks[i], breaks[i+1]]
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

  heatmap: ({requester, dataSource, timeAttribute, filter, forceInterval, condensedCommand, approximate, priority}, callback) ->
    druidQuery = new DruidQueryBuilder(dataSource, timeAttribute, forceInterval, approximate, priority)

    try
      # filter
      druidQuery.addFilter(filter)

      # split
      druidQuery.addSplit(condensedCommand.split)

      # apply
      if condensedCommand.applies.length
        for apply in condensedCommand.applies
          druidQuery.addApply(apply)
      else
        druidQuery.addDummyApply()

      if condensedCommand.combine
        druidQuery.addCombine(condensedCommand.combine)

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
      context or= {}
      throw new TypeError("query must be a FacetQuery") unless query instanceof FacetQuery
    catch e
      callback(e)
      return

    init = true
    rootSegment = {
      parent: null
      _filter: andFilters(filter, query.getFilter())
    }
    segments = [rootSegment]

    condensedGroups = query.getGroups()

    queryDruid = (condensedCommand, lastCmd, callback) ->
      if condensedCommand.split
        switch condensedCommand.split.bucket
          when 'identity'
            if approximate
              if condensedCommand.combine.limit?
                queryFn = druidQueryFns.topN
              else
                queryFn = druidQueryFns.allData
            else
              queryFn = druidQueryFns.groupBy
          when 'timeDuration', 'timePeriod'
            queryFn = druidQueryFns.timeseries
          when 'continuous'
            queryFn = druidQueryFns.histogram
          when 'tuple'
            if approximate and condensedCommand.split.splits.length is 2
              queryFn = druidQueryFns.heatmap
            else
              queryFn = druidQueryFns.groupBy
          else
            callback({ message: 'unsupported query' }); return
      else
        queryFn = druidQueryFns.all

      queryForSegment = (parentSegment, callback) ->
        queriesMade++
        if queryLimit < queriesMade
          callback({ message: 'query limit exceeded' })
          return

        queryFn({
          requester
          dataSource
          timeAttribute
          filter: parentSegment._filter
          forceInterval
          condensedCommand
          approximate
          priority: context.priority
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
                  _filter: andFilters(parentSegment._filter, condensedCommand.split.getFilterFor(prop[condensedCommand.split.name]))
                }

            parentSegment.splits = splits = props.map(propToSplit)
          else
            prop = props[0]
            driverUtil.cleanProp(prop)
            splits = [{
              parent: parentSegment
              prop
              _filter: parentSegment._filter
            }]

          callback(null, splits)
          return
        )
        return

      if condensedCommand.split?.segmentFilter
        segmentFilterFn = driverUtil.makeBucketFilterFn(condensedCommand.split.segmentFilter)
        driverUtil.inPlaceFilter(segments, segmentFilterFn)

      # do the query in parallel
      async.mapLimit(
        segments
        concurrentQueryLimit
        queryForSegment
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
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
