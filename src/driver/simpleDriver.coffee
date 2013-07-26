`(typeof window === 'undefined' ? {} : window)['simpleDriver'] = (function(module, require){"use strict"; var exports = module.exports`

async = require('async')
driverUtil = require('./driverUtil')

# -----------------------------------------------------

filterFns = {
  false: ->
    return -> false

  is: ({attribute, value}) ->
    return (d) -> d[attribute] is value

  in: ({attribute, values}) ->
    return (d) -> d[attribute] in values

  fragments: ({attribute, fragments}) ->
    throw new Error("implement this")

  match: ({attribute, expression}) ->
    expression = new RegExp(expression)
    return (d) -> expression.test(d[attribute])

  within: ({attribute, range}) ->
    throw new TypeError("range must be an array of two things") unless Array.isArray(range) and range.length is 2
    if range[0] instanceof Date
      return (d) -> new Date(range[0]) <= new Date(d[attribute]) < new Date(range[1])
    return (d) -> range[0] <= d[attribute] < range[1]

  not: ({filter}) ->
    throw new TypeError("filter must be a filter object") unless typeof filter is 'object'
    filter = makeFilterFn(filter)
    return (d) -> not filter(d)

  and: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeFilterFn)
    return (d) ->
      for filter in filters
        return false unless filter(d)
      return true

  or: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeFilterFn)
    return (d) ->
      for filter in filters
        return true if filter(d)
      return false
}

makeFilterFn = (filter) ->
  throw new Error("type not defined in filter") unless filter.hasOwnProperty('type')
  throw new Error("invalid type in filter") unless typeof filter.type is 'string'
  filterFn = filterFns[filter.type]
  throw new Error("filter type '#{filter.type}' not defined") unless filterFn
  return filterFn(filter)

# ------------------------
splitFns = {
  identity: ({attribute}) ->
    throw new Error('attribute not defined') unless typeof attribute is 'string'
    return (d) -> d[attribute] ? null

  continuous: ({attribute, size, offset}) ->
    throw new Error('attribute not defined') unless typeof attribute is 'string'
    throw new Error("size has to be positive (is: #{size})") unless size > 0
    return (d) ->
      num = Number(d[attribute])
      return null if isNaN(num)
      b = Math.floor((num + offset) / size) * size - offset
      return [b, b + size]

  timeDuration: ({attribute, duration, offset}) ->
    throw new Error("not implemented yet") # todo

  timePeriod: ({attribute, period, timezone}) ->
    throw new Error('attribute not defined') unless typeof attribute is 'string'
    timezone ?= 'Etc/UTC'
    throw new Error('only UTC is supported for now') unless timezone is 'Etc/UTC'
    switch period
      when 'PT1S'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCMilliseconds(0)
          de = new Date(ds)
          de.setUTCMilliseconds(1000)
          return [ds, de]

      when 'PT1M'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCSeconds(0, 0)
          de = new Date(ds)
          de.setUTCSeconds(60)
          return [ds, de]

      when 'PT1H'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCMinutes(0, 0, 0)
          de = new Date(ds)
          de.setUTCMinutes(60)
          return [ds, de]

      when 'P1D'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCHours(0, 0, 0, 0)
          de = new Date(ds)
          de.setUTCHours(24)
          return [ds, de]

  tuple: ({splits}) ->
    tupleSplits = splits.map(makeSplitFn)
    return (d) -> tupleSplits.map((sf) -> sf(d))
}

makeSplitFn = (split) ->
  splitFn = splitFns[split.bucket]
  throw new Error("No such bucket `#{split.bucket}` in split") unless splitFn
  return splitFn(split)


# ----------------------------
aggregateFns = {
  constant: ({value}) -> () ->
    return Number(value)

  count: -> (ds) ->
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
    return min

  max: ({attribute}) -> (ds) ->
    max = -Infinity
    max = Math.max(max, Number(d[attribute])) for d in ds
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
    throw new Error("not implemented yet (ToDo)")
    return
}

arithmeticFns = {
  add: ({operands}) ->
    [lhs, rhs] = operands.map(makeApplyFn)
    return (ds) -> lhs(ds) + rhs(ds)


  subtract: ({operands}) ->
    [lhs, rhs] = operands.map(makeApplyFn)
    return (ds) -> lhs(ds) - rhs(ds)


  multiply: ({operands}) ->
    [lhs, rhs] = operands.map(makeApplyFn)
    return (ds) -> lhs(ds) * rhs(ds)


  divide: ({operands}) ->
    [lhs, rhs] = operands.map(makeApplyFn)
    return (ds) -> lhs(ds) / rhs(ds)
}

makeApplyFn = (apply) ->
  if apply.aggregate
    aggregateFn = aggregateFns[apply.aggregate]
    throw new Error("unsupported aggregate '#{apply.aggregate}' in apply") unless aggregateFn
    rawApplyFn = aggregateFn(apply)
    if apply.filter
      filterFn = makeFilterFn(apply.filter)
      return (ds) -> rawApplyFn(ds.filter(filterFn))
    else
      return rawApplyFn
  else if apply.arithmetic
    arithmeticFn = arithmeticFns[apply.arithmetic]
    throw new Error("unsupported arithmetic '#{apply.arithmetic}' in apply") unless arithmeticFn
    return arithmeticFn(apply)
  else
    throw new Error("apply must have an aggregate or an arithmetic")
  return

# -------------------
directionFns = {
  ascending: (a, b) ->
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

compareFns = {
  natural: ({prop, direction}) ->
    directionFn = directionFns[direction]
    throw new Error("direction has to be 'ascending' or 'descending'") unless directionFn
    return (a, b) -> directionFn(a.prop[prop], b.prop[prop])

  caseInsensetive: ({prop, direction}) ->
    directionFn = directionFns[direction]
    throw new Error("direction has to be 'ascending' or 'descending'") unless directionFn
    return (a, b) -> directionFn(String(a.prop[prop]).toLowerCase(), String(b.prop[prop]).toLowerCase())
}

makeCompareFn = (sortCompare) ->
  compareFn = compareFns[sortCompare.compare]
  throw new Error("No such compare `#{sortCompare.compare}` in combine.sort") unless compareFn
  return compareFn(sortCompare)


combineFns = {
  slice: ({sort, limit}) ->
    if sort
      compareFn = makeCompareFn(sort)

    return (segments) ->
      if compareFn
        segments.sort(compareFn)

      if limit?
        driverUtil.inPlaceTrim(segments, limit)

      return

  matrix: () ->
    throw new Error("not implemented yet")
}

makeCombineFn = (combine) ->
  throw new Error("combine not defined in combine") unless combine.hasOwnProperty('combine')
  combineFn = combineFns[combine.combine]
  throw new Error("unsupported combine '#{combine.combine}' in combine") unless combineFn
  return combineFn(combine)



computeQuery = (data, query) ->
  throw new Error("query not supplied") unless query
  throw new Error("invalid query") unless Array.isArray(query)

  rootSegment = {
    prop: {}
    parent: null
    _raw: data
  }
  originalSegmentGroups = segmentGroups = [[rootSegment]]

  lastSplit = null
  for cmd in query
    switch cmd.operation
      when 'filter'
        filterFn = makeFilterFn(cmd)
        for segmentGroup in segmentGroups
          driverUtil.inPlaceFilter(segmentGroup, (segment) ->
            segment._raw = segment._raw.filter(filterFn)
            return segment._raw.length > 0
          )

      when 'split'
        lastSplit = cmd
        propName = cmd.name
        throw new Error("name not defined in split") unless propName
        throw new TypeError("invalid name in split") unless typeof propName is 'string'
        splitFn = makeSplitFn(cmd)
        bucketFilterFn = if cmd.bucketFilter then driverUtil.makeBucketFilterFn(cmd.bucketFilter) else null
        segmentGroups = driverUtil.filterMap driverUtil.flatten(segmentGroups), (segment) ->
          return if bucketFilterFn and not bucketFilterFn(segment)
          keys = []
          buckets = {}
          bucketValue = {}
          for d in segment._raw
            key = splitFn(d)
            throw new Error("bucket returned undefined") unless key? # ToDo: handle nulls
            keyString = String(key)

            if not buckets[keyString]
              keys.push(keyString)
              buckets[keyString] = []
              bucketValue[keyString] = key
            buckets[keyString].push(d)

          segment.splits = keys.map((keyString) ->
            prop = {}
            prop[propName] = bucketValue[keyString]

            return {
              _raw: buckets[keyString]
              prop
              parent: segment
            }
          )
          return segment.splits

      when 'apply'
        propName = cmd.name
        throw new Error("name not defined in apply") unless propName
        throw new TypeError("invalid name in apply") unless typeof propName is 'string'

        applyFn = makeApplyFn(cmd)
        for segmentGroup in segmentGroups
          for segment in segmentGroup
            segment.prop[propName] = applyFn(segment._raw)

      when 'combine'
        throw new Error("combine called without split") unless lastSplit
        lastSplit = null

        combineFn = makeCombineFn(cmd)
        for segmentGroup in segmentGroups
          combineFn(segmentGroup) # In place

      else
        throw new Error("unrecognizable command") unless typeof cmd is 'object'
        throw new Error("operation not defined") unless cmd.hasOwnProperty('operation')
        throw new Error("invalid operation") unless typeof cmd.operation is 'string'
        throw new Error("unknown operation '#{cmd.operation}'")

  return driverUtil.cleanSegments(originalSegmentGroups[0][0] or {})


module.exports = (data) -> (request, callback) ->
  try
    throw new Error("request not supplied") unless request
    {context, query} = request
    result = computeQuery(data, query)
  catch e
    callback({ message: e.message, stack: e.stack }); return

  callback(null, result)
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
