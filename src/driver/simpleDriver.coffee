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

  time: ({attribute, duration, timezone}) ->
    throw new Error('attribute not defined') unless typeof attribute is 'string'
    switch duration
      when 'second'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCMilliseconds(0)
          de = new Date(ds)
          de.setUTCMilliseconds(1000)
          return [ds, de]

      when 'minute'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCSeconds(0, 0)
          de = new Date(ds)
          de.setUTCSeconds(60)
          return [ds, de]

      when 'hour'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCMinutes(0, 0, 0)
          de = new Date(ds)
          de.setUTCMinutes(60)
          return [ds, de]

      when 'day'
        return (d) ->
          ds = new Date(d[attribute])
          return null if isNaN(ds)
          ds.setUTCHours(0, 0, 0, 0)
          de = new Date(ds)
          de.setUTCHours(24)
          return [ds, de]
}

applyFns = {
  constant: ({value}) -> () ->
    return value

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
    throw "not implemented yet (ToDo)"
    return
}

compareFns = {
  ascending: (a, b) ->
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

sortFns = {
  natural: ({prop, direction}) ->
    compareFn = compareFns[direction]
    throw "direction has to be 'ascending' or 'descending'" unless compareFn
    return (a, b) -> compareFn(a.prop[prop], b.prop[prop])

  caseInsensetive: ({prop, direction}) ->
    compareFn = compareFns[direction]
    throw "direction has to be 'ascending' or 'descending'" unless compareFn
    return (a, b) -> compareFn(String(a.prop[prop]).toLowerCase(), String(b.prop[prop]).toLowerCase())
}

computeQuery = (data, query) ->
  throw new Error("query not given") unless query

  rootSegment = {
    _raw: data
    prop: {}
  }
  segmentGroups = [[rootSegment]]

  for cmd in query
    switch cmd.operation
      when 'split'
        propName = cmd.name
        throw new Error("'name' not defined in split") unless propName
        splitFn = splitFns[cmd.bucket]
        throw new Error("No such bucket `#{cmd.bucket}` in split") unless splitFn
        bucketFn = splitFn(cmd)
        segmentGroups = driverUtil.flatten(segmentGroups).map (segment) ->
          keys = []
          buckets = {}
          bucketValue = {}
          for d in segment._raw
            key = bucketFn(d)
            throw new Error("Bucket returned undefined") unless key? # ToDo: handle nulls
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
            }
          )
          driverUtil.cleanSegment(segment)
          return segment.splits

      when 'apply'
        propName = cmd.name
        throw new Error("'name' not defined in apply") unless propName
        applyFn = applyFns[cmd.aggregate]
        throw new Error("No such aggregate `#{cmd.aggregate}` in apply") unless applyFn
        aggregatorFn = applyFn(cmd)
        for segmentGroup in segmentGroups
          for segment in segmentGroup
            segment.prop[propName] = aggregatorFn(segment._raw)

      when 'combine'
        if cmd.sort
          for segmentGroup in segmentGroups
            sortFn = sortFns[cmd.sort.compare]
            throw new Error("No such compare `#{cmd.sort.compare}` in combine.sort") unless sortFn
            compareFn = sortFn(cmd.sort)
            for segmentGroup in segmentGroups
              segmentGroup.sort(compareFn)

        if cmd.limit?
          limit = cmd.limit
          for segmentGroup in segmentGroups
            segmentGroup.splice(limit, segmentGroup.length - limit)

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  # Cleanup _raw data on last segment
  for segmentGroup in segmentGroups
    segmentGroup.forEach(driverUtil.cleanSegment)

  return rootSegment


exports = (data) -> (query, callback) ->
  try
    result = computeQuery(data, query)
  catch e
    callback({ message: e.message, stack: e.stack }); return

  callback(null, result)
  return

# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['simpleDriver'] = exports else module.exports = exports

