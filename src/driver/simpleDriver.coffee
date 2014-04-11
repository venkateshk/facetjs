async = require('async')
{ Duration } = require('./chronology')
driverUtil = require('./driverUtil')
SegmentTree = require('./segmentTree')
{FacetFilter, FacetSplit, FacetApply, FacetCombine, FacetQuery} = require('../query')

# -----------------------------------------------------

splitFns = {
  identity: ({attribute}) ->
    return (d) -> d[attribute] ? null

  continuous: ({attribute, size, offset}) ->
    return (d) ->
      num = Number(d[attribute])
      return null if isNaN(num)
      b = Math.floor((num - offset) / size) * size + offset
      return [b, b + size]

  timePeriod: ({attribute, period, timezone}) ->
    duration = new Duration(period)
    return (d) ->
      ds = new Date(d[attribute])
      return null if isNaN(ds)
      ds = duration.floor(ds, timezone)
      return [ds, duration.move(ds, timezone, 1)]

  tuple: ({splits}) ->
    tupleSplits = splits.map(makeSplitFn)
    return (d) -> tupleSplits.map((sf) -> sf(d))
}

makeSplitFn = (split) ->
  throw new TypeError("split must be a FacetSplit") unless split instanceof FacetSplit
  splitFn = splitFns[split.bucket]
  throw new Error("split bucket '#{split.bucket}' not supported by driver") unless splitFn
  return splitFn(split)


# ----------------------------
aggregateFns = {
  constant: ({value}) -> return ->
    return Number(value)

  count: (dataset) -> (ds) ->
    return ds.length

  sum: ({attribute}) -> (ds) ->
    sum = 0
    sum += Number(d[attribute]) for d in ds
    return sum

  average: ({attribute}) -> (ds) ->
    sum = 0
    sum += Number(d[attribute]) for d in ds
    return sum / ds.length

  min: ({attribute}) -> (ds) ->
    min = +Infinity
    min = Math.min(min, Number(d[attribute])) for d in ds
    if isNaN(min)
      min = +Infinity
      min = Math.min(min, (new Date(d[attribute])).valueOf()) for d in ds
    return min

  max: ({attribute}) -> (ds) ->
    max = -Infinity
    max = Math.max(max, Number(d[attribute])) for d in ds
    if isNaN(max)
      max = -Infinity
      max = Math.max(max, (new Date(d[attribute])).valueOf()) for d in ds
    return max

  uniqueCount: ({attribute}) -> (ds) ->
    seen = {}
    count = 0
    for d in ds
      v = d[attribute]
      if not seen[v]
        count++
        seen[v] = 1
    return count

  quantile: ({attribute, quantile}) -> (ds) ->
    return null unless ds.length
    points = ds.map((d) -> Number(d[attribute]))
    points.sort((a, b) -> a - b)
    return points[Math.floor(points.length * quantile)]
}

arithmeticFns = {
  add: ([lhs, rhs]) -> (ds) ->
    return lhs(ds) + rhs(ds)

  subtract: ([lhs, rhs]) -> (ds) ->
    return lhs(ds) - rhs(ds)

  multiply: ([lhs, rhs]) -> (ds) ->
    return lhs(ds) * rhs(ds)

  divide: ([lhs, rhs]) -> (ds) ->
    return lhs(ds) / rhs(ds)
}

makeApplyFn = (apply) ->
  throw new TypeError("apply must be a FacetApply") unless apply instanceof FacetApply
  if apply.aggregate
    aggregateFn = aggregateFns[apply.aggregate]
    throw new Error("aggregate '#{apply.aggregate}' unsupported by driver") unless aggregateFn
    dataset = apply.getDataset()
    rawApplyFn = aggregateFn(apply)
    if apply.filter
      filterFn = apply.filter.getFilterFn()
      return (dss) -> rawApplyFn(dss[dataset].filter(filterFn))
    else
      return (dss) -> rawApplyFn(dss[dataset])
  else if apply.arithmetic
    arithmeticFn = arithmeticFns[apply.arithmetic]
    throw new Error("arithmetic '#{apply.arithmetic}' unsupported by driver") unless arithmeticFn
    return arithmeticFn(apply.operands.map(makeApplyFn))
  else
    throw new Error("apply must have an aggregate or an arithmetic")
  return

# -------------------
combineFns = {
  slice: ({sort, limit}) ->
    if sort
      segmentCompareFn = sort.getSegmentCompareFn()

    return (segments) ->
      if segmentCompareFn
        segments.sort(segmentCompareFn)

      if limit?
        driverUtil.inPlaceTrim(segments, limit)

      return

  matrix: ->
    throw new Error("matrix combine not implemented yet")
}

makeCombineFn = (combine) ->
  throw new TypeError("combine must be a FacetCombine") unless combine instanceof FacetCombine
  combineFn = combineFns[combine.method]
  throw new Error("method '#{combine.method}' unsupported by driver") unless combineFn
  return combineFn(combine)


computeQuery = (data, query) ->
  rootRaw = {}

  filtersByDataset = query.getFiltersByDataset()
  for datasetName, datasetFilter of filtersByDataset
    rootRaw[datasetName] = data.filter(datasetFilter.getFilterFn())

  rootSegment = new SegmentTree({prop: {}})
  rootSegment._raws = rootRaw
  originalSegmentGroups = segmentGroups = [[rootSegment]]

  groups = query.getCondensedCommands()
  for condensedCommand in groups
    split = condensedCommand.getSplit()
    applies = condensedCommand.getApplies()
    combine = condensedCommand.getCombine()

    if split
      propName = split.name
      parallelSplits = if split.bucket is 'parallel' then split.splits else [split]

      parallelSplitFns = {}
      for parallelSplit in parallelSplits
        parallelSplitFns[parallelSplit.getDataset()] = makeSplitFn(parallelSplit)

      segmentFilterFn = if split.segmentFilter then split.segmentFilter.getFilterFn() else null
      segmentGroups = driverUtil.filterMap driverUtil.flatten(segmentGroups), (segment) ->
        return if segmentFilterFn and not segmentFilterFn(segment)
        keys = []
        bucketsByDataset = {}
        bucketValue = {}
        for dataset, parallelSplitFn of parallelSplitFns
          buckets = {}
          for d in segment._raws[dataset]
            key = parallelSplitFn(d)
            #throw new Error("bucket returned undefined") unless key? # ToDo: handle nulls
            keyString = String(key)

            if not bucketValue.hasOwnProperty(keyString)
              keys.push(keyString)
              bucketValue[keyString] = key

            buckets[keyString] = [] unless buckets[keyString]
            buckets[keyString].push(d)
          bucketsByDataset[dataset] = buckets

        segment.setSplits(keys.map((keyString) ->
          prop = {}
          prop[propName] = bucketValue[keyString]

          raws = {}
          for dataset, buckets of bucketsByDataset
            raws[dataset] = buckets[keyString] or []

          newSplit = new SegmentTree({prop})
          newSplit._raws = raws
          return newSplit
        ))
        return segment.splits

    for apply in applies
      propName = apply.name
      applyFn = makeApplyFn(apply)
      for segmentGroup in segmentGroups
        for segment in segmentGroup
          segment.prop[propName] = applyFn(segment._raws)

    if combine
      combineFn = makeCombineFn(combine)
      for segmentGroup in segmentGroups
        combineFn(segmentGroup) # In place

  return (originalSegmentGroups[0][0] or new SegmentTree({})).selfClean()


introspectData = ({data, maxSample}) ->
  return null unless data.length
  sample = data.slice(0, maxSample)

  attributeNames = []
  for k of sample[0]
    continue if k is ''
    attributeNames.push(k)
  attributeNames.sort()

  maxYear = new Date().getUTCFullYear() + 5
  isDate = (dt) ->
    return false if not isNaN(dt) and Number(dt) < 3000
    dt = new Date(dt)
    return not isNaN(dt) and 1987 <= dt.getUTCFullYear() < maxYear

  isNumber = (n) ->
    return not isNaN(Number(n))

  isInteger = (n) ->
    return Number(n) is parseInt(n, 10)

  isString = (str) ->
    return typeof str is 'string'

  return attributeNames.map (attributeName) ->
    attribute = {
      name: attributeName
    }
    column = sample.map((d) -> d[attributeName]).filter((x) -> x not in [null, ''])
    if column.length
      if column.every(isDate)
        attribute.time = true

      if column.every(isNumber)
        attribute.numeric = true
        if column.every(isInteger)
          attribute.integer = true
      else
        if column.every(isString)
          attribute.categorical = true

    return attribute


module.exports = (dataGetter) ->
  dataError = null
  dataArray = null

  if Array.isArray(dataGetter)
    dataArray = dataGetter
  else if typeof dataGetter is 'function'
    waitingQueries = []
    dataGetter (err, data) ->
      dataError = err
      dataArray = data
      waitingQuery() for waitingQuery in waitingQueries
      waitingQueries = null
      return
  else
    throw new TypeError("dataGetter must be a function or raw data (array)")

  driver = (request, callback) ->
    try
      throw new Error("request not supplied") unless request
      {context, query} = request
      throw new Error("query not supplied") unless query
      throw new TypeError("query must be a FacetQuery") unless query instanceof FacetQuery
    catch e
      callback(e)
      return

    computeWithData = ->
      if dataError
        callback(dataError)
        return

      try
        result = computeQuery(dataArray, query)
      catch e
        callback(e)
        return

      callback(null, result)
      return

    if waitingQueries
      waitingQueries.push(computeWithData)
    else
      computeWithData()

    return

  driver.introspect = (opts, callback) ->
    {
      maxSample
    } = opts or {}

    doIntrospect = ->
      if dataError
        callback(dataError)
        return

      attributes = introspectData({
        data: dataArray
        maxSample: maxSample or 1000
      })

      callback(null, attributes)
      return

    if waitingQueries
      waitingQueries.push(doIntrospect)
    else
      doIntrospect()

    return

  return driver
