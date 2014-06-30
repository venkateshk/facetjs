async = require('async')
{ Duration } = require('chronology')
driverUtil = require('./driverUtil')
SegmentTree = require('./segmentTree')
{
  AttributeMeta
  UniqueAttributeMeta
  HistogramAttributeMeta
} = require('./attributeMeta')
{
  FacetQuery, CondensedCommand
  FacetFilter, TrueFilter, InFilter, AndFilter
  FacetSplit, FacetApply, CountApply, FacetCombine, SliceCombine
} = require('../query')

defaultAttributeMeta = AttributeMeta.default
uniqueAttributeMeta = new UniqueAttributeMeta()
histogramAttributeMeta = new HistogramAttributeMeta()

# -----------------------------------------------------

isString = (str) ->
  return typeof str is 'string'

# -----------------------------------------------------

arithmeticToDruidFn = {
  add: '+'
  subtract: '-'
  multiply: '*'
  divide: '/'
}

aggregateToJS = {
  count: ['0', (a, b) -> "#{a} + #{b}"]
  sum:   ['0', (a, b) -> "#{a} + #{b}"]
  min:   ['Infinity',  (a, b) -> "Math.min(#{a}, #{b})"]
  max:   ['-Infinity', (a, b) -> "Math.max(#{a}, #{b})"]
}

correctSingletonDruidResult = (result) ->
  return Array.isArray(result) and result.length <= 1 and (result.length is 0 or result[0].result)

emptySingletonDruidResult = (result) ->
  return result.length is 0

class DruidQueryBuilder
  @ALL_DATA_CHUNKS = 10000

  @FALSE_INTERVALS = ["1000-01-01/1000-01-02"]

  constructor: ({dataSource, @timeAttribute, @attributeMetas, @forceInterval, @approximate, @context}) ->
    @setDataSource(dataSource)
    throw new Error("must have a timeAttribute") unless isString(@timeAttribute)
    @queryType = 'timeseries'
    @granularity = 'all'
    @attributeMetas or= {}
    @filter = null
    @aggregations = []
    @postAggregations = []
    @nameIndex = 0
    @intervals = null
    @useCache = true

  setDataSource: (dataSource) ->
    if not (isString(dataSource) or (Array.isArray(dataSource) and dataSource.length and dataSource.every(isString)))
      throw new Error("`dataSource` must be a string or union array")

    if isString(dataSource)
      @dataSource = dataSource
    else
      @dataSource = {
        type: "union"
        dataSources: dataSource
      }

    return

  getAttributeMeta: (attribute) ->
    return @attributeMetas[attribute] if @attributeMetas[attribute]
    if /_hist$/.test(attribute)
      return histogramAttributeMeta
    if /^unique_/.test(attribute)
      return uniqueAttributeMeta
    return defaultAttributeMeta

  addToNamespace: (namespace, attribute) ->
    return namespace[attribute] if namespace[attribute]
    namespace[attribute] = "v#{@jsCount}"
    @jsCount++
    return namespace[attribute]

  # return { jsFilter, namespace }
  filterToJSHelper: (filter, namespace) ->
    switch filter.type
      when 'true', 'false' then filter.type

      when 'is'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        attributeMeta = @getAttributeMeta(filter.attribute)
        varName = @addToNamespace(namespace, filter.attribute)
        "#{varName} === '#{attributeMeta.serialize(filter.value)}'"

      when 'in'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        attributeMeta = @getAttributeMeta(filter.attribute)
        varName = @addToNamespace(namespace, filter.attribute)
        filter.values.map((value) -> "#{varName} === '#{attributeMeta.serialize(value)}'").join('||')

      when 'contains'
        throw new Error("can not filter on specific time") if filter.attribute is @timeAttribute
        varName = @addToNamespace(namespace, filter.attribute)
        "String(#{varName}).indexOf('#{filter.value}') !== -1"

      when 'not'
        "!(#{@filterToJSHelper(filter.filter, namespace)})"

      when 'and'
        filter.filters.map(((filter) -> "(#{@filterToJSHelper(filter, namespace)})"), this).join('&&')

      when 'or'
        filter.filters.map(((filter) -> "(#{@filterToJSHelper(filter, namespace)})"), this).join('||')

      else
        throw new Error("unknown JS filter type '#{filter.type}'")

  filterToJS: (filter) ->
    namespace = {}
    @jsCount = 0
    jsFilter = @filterToJSHelper(filter, namespace)
    return {
      jsFilter
      namespace
    }

  timelessFilterToDruid: (filter) ->
    return switch filter.type
      when 'true'
        null

      when 'false'
        throw new Error("should never get here")

      when 'is'
        attributeMeta = @getAttributeMeta(filter.attribute)
        {
          type: 'selector'
          dimension: filter.attribute
          value: attributeMeta.serialize(filter.value)
        }

      when 'in'
        attributeMeta = @getAttributeMeta(filter.attribute)
        {
          type: 'or'
          fields: filter.values.map(((value) ->
            return {
              type: 'selector'
              dimension: filter.attribute
              value: attributeMeta.serialize(value)
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
        if typeof r0 isnt 'number' or typeof r1 isnt 'number'
          throw new Error("apply within has to have a numeric range")
        {
          type: 'javascript'
          dimension: filter.attribute
          function: """
            function(a) {
              a = Number(a);
              return #{r0} <= a && a < #{r1};
            }
            """
        }

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


  addFilter: (filter) ->
    if filter.type is 'false'
      @intervals = DruidQueryBuilder.FALSE_INTERVALS
      @filter = null

    else
      extract = filter.extractFilterByAttribute(@timeAttribute)
      throw new Error("could not separate time filter") unless extract
      [timelessFilter, timeFilter] = extract

      @intervals = driverUtil.timeFilterToIntervals(timeFilter, @forceInterval)
      @filter = @timelessFilterToDruid(timelessFilter)

    return this


  addSplit: (split) ->
    throw new TypeError() unless split instanceof FacetSplit
    switch split.bucket
      when 'identity'
        @queryType = 'groupBy'
        #@granularity stays 'all'
        attributeMeta = @getAttributeMeta(split.attribute)
        if attributeMeta.type is 'range'
          separator = JSON.stringify(attributeMeta.separator or ';')
          @dimension = {
            type: 'extraction'
            dimension: split.attribute
            outputName: split.name
            dimExtractionFn: {
              type: 'javascript'
              function: """function(d) {
                var start = d.split(#{separator})[0];
                if(isNaN(start)) return 'null';
                var parts = Math.abs(start).split('.');
                d = ('000000000' + parts[0]).substr(-10);
                if(parts.length > 1) d += '.' + parts[1];
                if(start < 0) d = '-' + d;
                return d;
                }"""
            }
          }
        else
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

      when 'continuous'
        attributeMeta = @getAttributeMeta(split.attribute)
        if attributeMeta.type is 'histogram'
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
        else if attributeMeta.type is 'range'
          throw new Error("not implemented yet")
        else
          floorExpresion = driverUtil.continuousFloorExpresion({
            variable: "d"
            floorFn: "Math.floor"
            size: split.size
            offset: split.offset
          })

          @queryType = 'groupBy'
          #@granularity stays 'all'
          @dimension = {
            type: 'extraction'
            dimension: split.attribute
            outputName: split.name
            dimExtractionFn: {
              type: 'javascript'
              function: """
                function(d) {
                d = Number(d);
                if(isNaN(d)) return 'null';
                return #{floorExpresion};
                }"""
            }
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

  addAggregation: (aggregation) ->
    # Make sure unique by name
    for existingAggregation in @aggregations
      return if existingAggregation.name is aggregation.name
    @aggregations.push(aggregation)
    return

  addPostAggregation: (postAggregation) ->
    @postAggregations.push(postAggregation)
    return

  addAggregateApply: (apply) ->
    if apply.attribute is @timeAttribute
      throw new Error("can not aggregate apply on time attribute")

    attributeMeta = @getAttributeMeta(apply.attribute)
    switch apply.aggregate
      when 'constant'
        @addPostAggregation({
          name: apply.name
          type: "constant"
          value: apply.value
        })

      when 'count', 'sum', 'min', 'max'
        if @approximate and apply.aggregate in ['min', 'max'] and attributeMeta.type is 'histogram'
          histogramAggregationName = "_hist_" + apply.attribute
          aggregation = {
            name: histogramAggregationName
            type: "approxHistogramFold"
            fieldName: apply.attribute
          }
          options = apply.options or {}
          aggregation.lowerLimit = options.druidLowerLimit if options.druidLowerLimit?
          aggregation.upperLimit = options.druidUpperLimit if options.druidUpperLimit?
          aggregation.resolution = options.druidResolution if options.druidResolution
          @addAggregation(aggregation)

          @addPostAggregation({
            name: apply.name
            type: apply.aggregate
            fieldName: histogramAggregationName
          })

        else
          if apply.filter
            { jsFilter, namespace } = @filterToJS(apply.filter)
            fieldNames = []
            varNames = []
            for fieldName, varName of namespace
              fieldNames.push(fieldName)
              varNames.push(varName)

            [zero, jsAgg] = aggregateToJS[apply.aggregate]

            if apply.aggregate is 'count'
              jsIf = "(#{jsFilter}?1:#{zero})"
            else
              fieldNames.push(apply.attribute)
              varNames.push('a')
              jsIf = "(#{jsFilter}?a:#{zero})"

            @addAggregation({
              name: apply.name
              type: "javascript"
              fieldNames: fieldNames
              fnAggregate: "function(cur,#{varNames.join(',')}){return #{jsAgg('cur', jsIf)};}"
              fnCombine: "function(pa,pb){return #{jsAgg('pa', 'pb')};}"
              fnReset: "function(){return #{zero};}"
            })
          else
            aggregation = {
              name: apply.name
              type: if apply.aggregate is 'sum' then 'doubleSum' else apply.aggregate
            }
            aggregation.fieldName = apply.attribute if apply.aggregate isnt 'count'
            @addAggregation(aggregation)

      when 'uniqueCount'
        throw new Error("approximate queries not allowed") unless @approximate
        throw new Error("filtering uniqueCount unsupported by driver") if apply.filter

        if attributeMeta.type is 'unique'
          @addAggregation({
            name: apply.name
            type: "hyperUnique"
            fieldName: apply.attribute
          })
        else
          @addAggregation({
            name: apply.name
            type: "cardinality"
            fieldNames: [apply.attribute]
            byRow: true
          })

      when 'quantile'
        throw new Error("approximate queries not allowed") unless @approximate

        histogramAggregationName = "_hist_" + apply.attribute
        aggregation = {
          name: histogramAggregationName
          type: "approxHistogramFold"
          fieldName: apply.attribute
        }
        options = apply.options or {}
        aggregation.lowerLimit = options.druidLowerLimit if options.druidLowerLimit?
        aggregation.upperLimit = options.druidUpperLimit if options.druidUpperLimit?
        aggregation.resolution = options.druidResolution if options.druidResolution
        @addAggregation(aggregation)

        @addPostAggregation({
          name: apply.name
          type: "quantile"
          fieldName: histogramAggregationName
          probability: apply.quantile
        })

      else
        throw new Error("unsupported aggregate '#{apply.aggregate}'")

    return

  arithmeticToPostAggregation: (apply) ->
    if apply.aggregate
      # This is a leaf node
      if apply.aggregate is 'constant'
        return {
          type: "constant"
          value: apply.value
        }
      else
        return {
          type: if apply.aggregate is 'uniqueCount' then 'hyperUniqueCardinality' else 'fieldAccess'
          fieldName: apply.name
        }

    druidFn = arithmeticToDruidFn[apply.arithmetic]
    throw new Error("unsupported arithmetic '#{apply.arithmetic}'") unless druidFn

    return {
      type: "arithmetic"
      fn: druidFn
      fields: apply.operands.map(@arithmeticToPostAggregation, this)
    }

  addArithmeticApply: (apply) ->
    postAggregation = @arithmeticToPostAggregation(apply)
    postAggregation.name = apply.name
    @addPostAggregation(postAggregation)
    return

  addApplies: (applies) ->
    if applies.length is 0
      @addAggregateApply(new CountApply({ name: '_dummy' }))
    else
      { aggregates, arithmetics } = FacetApply.breaker(applies, true)
      @addAggregateApply(apply) for apply in aggregates
      @addArithmeticApply(apply) for apply in arithmetics

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

            if @getAttributeMeta(@dimension.dimension).type is 'large'
              @context.doAggregateTopNMetricFirst = true

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
    emptyContext = true
    queryContext = {}
    for k, v of @context
      emptyContext = false
      queryContext[k] = v

    if not @useCache
      emptyContext = false
      queryContext.useCache = false
      queryContext.populateCache = false

    query = {
      @queryType
      @dataSource
      @granularity
      @intervals
    }

    query.context = queryContext unless emptyContext
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
      queryBuilder
        .addFilter(filter)
        .addApplies(condensedCommand.applies)

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      if not correctSingletonDruidResult(ds)
        err = new Error("unexpected result from Druid (all)")
        err.result = ds
        callback(err)
        return

      if emptySingletonDruidResult(ds)
        callback(null, [condensedCommand.getZeroProp()])
      else
        callback(null, ds.map((d) -> d.result))

      return
    return

  timeBoundry: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    applies = condensedCommand.applies
    if not applies.every((apply) -> apply.attribute is queryBuilder.timeAttribute and apply.aggregate in ['min', 'max'])
      callback(new Error("can not mix and match min / max time with other aggregates (for now)"))
      return

    queryObj = {
      queryType: 'timeBoundary'
      dataSource: queryBuilder.dataSource
    }

    maxTimeOnly = applies.length is 1 and applies[0].aggregate is 'max'
    if maxTimeOnly
      # If there is only a max apply then use maxTime instead
      queryObj.queryType = 'maxTime'

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      if not correctSingletonDruidResult(ds) or ds.length isnt 1
        err = new Error("unexpected result from Druid (#{queryObj.queryType})")
        err.result = ds
        callback(err)
        return

      result = ds[0].result
      prop = {}
      for {name, aggregate} in applies
        prop[name] = new Date(if maxTimeOnly then result else result[aggregate + 'Time'])

      callback(null, [prop])
      return

    return

  timeseries: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      timePropName = condensedCommand.split.name

      timezone = condensedCommand.split.timezone or 'Etc/UTC'
      splitDuration = new Duration(condensedCommand.split.period)
      canonicalDurationLengthAndThenSome = splitDuration.canonicalLength() * 1.5
      props = ds.map (d, i) ->
        rangeStart = new Date(d.timestamp)
        next = ds[i + 1]
        next = new Date(next.timestamp) if next

        if next and rangeStart < next and next - rangeStart < canonicalDurationLengthAndThenSome
          rangeEnd = next
        else
          rangeEnd = splitDuration.move(rangeStart, timezone, 1)

        prop = d.result
        prop[timePropName] = [rangeStart, rangeEnd]
        return prop

      combine = condensedCommand.getCombine()
      if combine.sort
        if combine.sort.prop is timePropName
          if combine.sort.direction is 'descending'
            props.reverse()
        else
          props.sort(combine.sort.getCompareFn())

      if combine.limit?
        limit = combine.limit
        driverUtil.inPlaceTrim(props, limit)

      callback(null, props)
      return
    return

  topN: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    split = condensedCommand.getSplit()
    try
      queryBuilder
        .addFilter(filter)
        .addSplit(split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine())

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      if not correctSingletonDruidResult(ds)
        err = new Error("unexpected result from Druid (topN)")
        err.result = ds
        callback(err)
        return

      ds = if emptySingletonDruidResult(ds) then [] else ds[0].result

      attributeMeta = queryBuilder.getAttributeMeta(split.attribute)
      if attributeMeta.type is 'range'
        splitProp = split.name
        rangeSize = attributeMeta.rangeSize
        for d in ds
          if d[splitProp] in [null, 'null'] # ToDo: remove 'null' when druid is fixed
            d[splitProp] = null
          else
            start = Number(d[splitProp])
            d[splitProp] = [start, driverUtil.safeAdd(start, rangeSize)]

      else if split.bucket is 'continuous'
        splitProp = split.name
        splitSize = split.size
        for d in ds
          if d[splitProp] in [null, 'null'] # ToDo: remove 'null' when druid is fixed
            d[splitProp] = null
          else
            start = Number(d[splitProp])
            d[splitProp] = [start, driverUtil.safeAdd(start, splitSize)]

      callback(null, ds)
      return
    return

  allData: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    allDataChunks = DruidQueryBuilder.ALL_DATA_CHUNKS

    combine = condensedCommand.getCombine()
    try
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(new SliceCombine({
          sort: {
            compare: 'natural'
            prop: condensedCommand.split.name
            direction: combine.sort.direction or 'ascending'
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
            err = new Error("unexpected result from Druid (topN/allData)")
            err.result = ds
            callback(err)
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
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine())

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      callback(null, ds.map((d) -> d.event))
      return
    return

  histogram: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    if not condensedCommand.applies.every(({aggregate}) -> aggregate is 'count')
      callback(new Error("only count aggregated applies are supported"))
      return

    try
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        # applies are constrained to count
        # combine has to be computed in post processing

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      if not correctSingletonDruidResult(ds)
        err = new Error("unexpected result from Druid (histogram)")
        err.result = ds
        callback(err)
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

      combine = condensedCommand.getCombine()
      if combine.sort
        if combine.sort.prop is histName
          if combine.sort.direction is 'descending'
            props.reverse()
        else
          props.sort(combine.sort.getCompareFn())

      if combine.limit?
        limit = combine.limit
        driverUtil.inPlaceTrim(props, limit)

      callback(null, props)
      return
    return

  heatmap: ({requester, queryBuilder, filter, parentSegment, condensedCommand}, callback) ->
    try
      queryBuilder
        .addFilter(filter)
        .addSplit(condensedCommand.split)
        .addApplies(condensedCommand.applies)
        .addCombine(condensedCommand.getCombine())

      queryObj = queryBuilder.getQuery()
    catch e
      callback(e)
      return

    requester {query: queryObj}, (err, ds) ->
      if err
        callback(err)
        return

      if not correctSingletonDruidResult(ds)
        err = new Error("unexpected result from Druid (heatmap)")
        err.result = ds
        callback(err)
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
  queryBuilder = new DruidQueryBuilder(builderSettings)
  split = condensedCommand.getSplit()
  if split
    switch split.bucket
      when 'identity'
        if approximate
          if condensedCommand.getCombine().limit?
            queryFnName = 'topN'
          else
            queryFnName = 'allData'
        else
          queryFnName = 'groupBy'
      when 'timePeriod'
        queryFnName = 'timeseries'
      when 'continuous'
        attributeMeta = queryBuilder.getAttributeMeta(split.attribute)
        if attributeMeta.type is 'histogram'
          queryFnName = 'histogram'
        else
          queryFnName = 'topN'
      when 'tuple'
        if approximate and split.splits.length is 2
          queryFnName = 'heatmap'
        else
          queryFnName = 'groupBy'
      else
        err = new Error('unsupported split bucket')
        err.split = split.valueOf()
        callback(err)
        return
  else
    if condensedCommand.applies.some((apply) -> apply.attribute is timeAttribute and apply.aggregate in ['min', 'max'])
      queryFnName = 'timeBoundry'
    else
      queryFnName = 'all'

  queryFn = DruidQueryBuilder.queryFns[queryFnName]

  queryFn({
    requester
    queryBuilder
    filter
    parentSegment
    condensedCommand
  }, callback)
  return


addSplitName = (split, name) ->
  splitSpec = split.valueOf()
  splitSpec.name = name
  return FacetSplit.fromSpec(splitSpec)


# Split up the condensed command into condensed commands contained within the dataset
splitupCondensedCommand = (condensedCommand) ->
  datasets = condensedCommand.getDatasets()
  combine = condensedCommand.getCombine()

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
    datasetSplit = null
    if condensedCommand.split
      splitName = condensedCommand.split.name
      for subSplit in condensedCommand.split.splits
        continue unless subSplit.getDataset() is dataset
        datasetSplit = addSplitName(subSplit, splitName)
        break

    datasetCondensedCommand = new CondensedCommand()
    datasetCondensedCommand.setSplit(datasetSplit) if datasetSplit
    perDatasetInfo.push {
      dataset
      condensedCommand: datasetCondensedCommand
    }

  # Segregate applies
  {
    appliesByDataset
    postProcessors
    trackedSegregation: sortApplySegregation
  } = FacetApply.segregate(condensedCommand.applies, combine?.sort?.prop)

  for info in perDatasetInfo
    applies = appliesByDataset[info.dataset] or []
    info.condensedCommand.addApply(apply) for apply in applies

  # Setup combines
  if combine
    sort = combine.sort
    if sort
      splitName = condensedCommand.split.name
      if sortApplySegregation.length is 0
        # Sorting on splitting prop
        for info in perDatasetInfo
          info.condensedCommand.setCombine(combine)
      else if sortApplySegregation.length is 1
        # Sorting on regular apply
        mainDataset = sortApplySegregation[0].dataset

        for info in perDatasetInfo
          if info.dataset is mainDataset
            info.condensedCommand.setCombine(combine)
          else
            info.driven = true
            info.condensedCommand.setCombine(new SliceCombine({
              sort: {
                compare: 'natural'
                direction: 'descending'
                prop: splitName
              }
              limit: combine.limit
            }))
      else
        # Sorting on a post apply
        for info in perDatasetInfo
          infoApplyName = driverUtil.find(sortApplySegregation, ({dataset}) -> dataset is info.dataset)
          if infoApplyName
            # has a part of the apply that will be combined into the sorting apply
            sortProp = infoApplyName.applyName
          else
            sortProp = splitName
            info.driven = true

          info.condensedCommand.setCombine(new SliceCombine({
            sort: {
              compare: 'natural'
              direction: 'descending'
              prop: sortProp
            }
            limit: 1000
          }))

    else
      # no sort... do not do anything for now
      null
  else
    # no combine... so do not add one
    null

  return {
    postProcessors
    perDatasetInfo
  }


# Make a multi-dataset query
multiDatasetQuery = ({parentSegment, condensedCommand, builderSettings, requester}, callback) ->
  datasets = condensedCommand.getDatasets()
  split = condensedCommand.getSplit()
  combine = condensedCommand.getCombine()

  if datasets.length is 0
    # If there are no datasets it means that this is a 'no-op' query, it has no splits or applies
    callback(null, [{}])
    return

  if datasets.length is 1
    # If there is only one dataset just make the single query (shortcut)
    DruidQueryBuilder.makeSingleQuery({
      parentSegment
      filter: parentSegment._filtersByDataset[datasets[0]]
      condensedCommand
      builderSettings
      requester
    }, callback)
    return

  { postProcessors, perDatasetInfo } = splitupCondensedCommand(condensedCommand)

  performApplyCombine = (result) ->
    for postProcessor in postProcessors
      result.forEach(postProcessor)

    if combine
      if combine.sort
        result.sort(combine.sort.getCompareFn())

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
      if split then [split.name] else []
      allApplyNames
      driverResults
    )

    if hasDriven and split
      # make filter
      splitName = split.name

      drivenQueries = driverUtil.filterMap perDatasetInfo, (info) ->
        return unless info.driven

        throw new Error("This (#{split.bucket}) split not implemented yet") unless info.condensedCommand.split.bucket is 'identity'
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
          [splitName]
          allApplyNames
          [driverResult].concat(drivenResults)
        )
        performApplyCombine(fullResult)
        callback(null, fullResult)
        return
    else
      performApplyCombine(driverResult)
      callback(null, driverResult)
    return

  return


# This is the Druid driver. It translates facet queries to Druid
#
# @param {Requester} requester, a function to make requests to Druid
# @param {string} dataSource, name of the datasource in Druid or the union spec
# @param {string} timeAttribute [optional, default="time"], name by which the time attribute will be referred to
# @param {Object} attributeMetas, meta attribute information
# @param {boolean} approximate [optional, default=false], allow use of approximate queries
# @param {Filter} filter [optional, default=null], the filter that should be applied to the data
# @param {boolean} forceInterval [optional, default=false], if true will not execute queries without a time constraint
# @param {number} concurrentQueryLimit [optional, default=16], max number of queries to execute concurrently
# @param {number} queryLimit [optional, default=Infinity], max query complexity
#
# @return {FacetDriver} the driver that does the requests

module.exports = ({requester, dataSource, timeAttribute, attributeMetas, approximate, filter, forceInterval, concurrentQueryLimit, queryLimit}) ->
  throw new Error("must have a requester") unless typeof requester is 'function'
  timeAttribute or= 'time'
  approximate ?= true
  concurrentQueryLimit or= 16
  queryLimit or= Infinity
  attributeMetas or= {}
  for k, v of attributeMetas
    throw new TypeError("`attributeMeta` for attribute '#{k}' must be an AttributeMeta") unless v instanceof AttributeMeta

  queriesMade = 0
  driver = (request, callback) ->
    try
      throw new Error("request not supplied") unless request
      {context, query} = request
      throw new Error("query not supplied") unless query
      throw new TypeError("query must be a FacetQuery") unless query instanceof FacetQuery
      context or= {}
    catch e
      callback(e)
      return

    init = true
    rootSegment = new SegmentTree({prop:{}})
    rootSegment._filtersByDataset = query.getFiltersByDataset(filter)
    segments = [rootSegment]

    condensedGroups = query.getCondensedCommands()

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
            err = new Error('query limit exceeded')
            err.limit = queryLimit
            callback(err)
            return

          multiDatasetQuery({
            requester
            builderSettings: {
              dataSource
              timeAttribute
              attributeMetas
              forceInterval
              approximate
              context
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
                (prop) -> new SegmentTree({prop})
              else
                (prop) ->
                  newSegmentTree = new SegmentTree({prop})
                  newSegmentTree._filtersByDataset = FacetFilter.andFiltersByDataset(
                    parentSegment._filtersByDataset
                    condensedCommand.split.getFilterByDatasetFor(prop)
                  )
                  return newSegmentTree

              parentSegment.setSplits(props.map(propToSplit))
            else
              newSegmentTree = new SegmentTree({ prop: props[0] })
              newSegmentTree._filtersByDataset = parentSegment._filtersByDataset
              parentSegment.setSplits([newSegmentTree])

            callback(null, parentSegment.splits)
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

        callback(null, (rootSegment or new SegmentTree({})).selfClean())
        return
    )
    return

  driver.introspect = (opts, callback) ->
    requester {
      query: {
        queryType: 'introspect'
        dataSource: if Array.isArray(dataSource) then dataSource[0] else dataSource
      }
    }, (err, ret) ->
      if err
        callback(err)
        return

      attributes = [{
        name: timeAttribute
        time: true
      }]

      for dimension in ret.dimensions.sort()
        attributes.push({
          name: dimension
          categorical: true
        })

      for metric in ret.metrics.sort()
        continue if metric.indexOf('_hist') isnt -1 or metric.indexOf('unique_') is 0
        attributes.push({
          name: metric
          numeric: true
        })

      callback(null, attributes)
      return
    return

  return driver

module.exports.DruidQueryBuilder = DruidQueryBuilder
