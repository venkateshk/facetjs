# Utils

flatten = (ar) -> Array::concat.apply([], ar)

# ===================================

splitFns = {
  natural: ({attribute}) -> (d) -> d[attribute]

  even: ({attribute, size, offset}) -> (d) ->
    b = Math.floor((d[attribute] + offset) / size) * size
    return [b, b + size]

  time: ({attribute, duration}) ->
    switch duration
      when 'second'
        return (d) ->
          ds = new Date(d[attribute])
          ds.setUTCMilliseconds(0)
          de = new Date(ds)
          de.setUTCMilliseconds(1000)
          return [ds, de]

      when 'minute'
        return (d) ->
          ds = new Date(d[attribute])
          ds.setUTCSeconds(0, 0)
          de = new Date(ds)
          de.setUTCSeconds(60)
          return [ds, de]

      when 'hour'
        return (d) ->
          ds = new Date(d[attribute])
          ds.setUTCMinutes(0, 0, 0)
          de = new Date(ds)
          de.setUTCMinutes(60)
          return [ds, de]

      when 'day'
        return (d) ->
          ds = new Date(d[attribute])
          ds.setUTCHours(0, 0, 0, 0)
          de = new Date(ds)
          de.setUTCHours(24)
          return [ds, de]
}

applyFns = {
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

  unique: ({attribute}) -> (ds) ->
    seen = {}
    count = 0
    for d in ds
      v = d[attribute]
      if not seen[v]
        count++
        seen[v] = 1
    return count
}


ascending = (a, b) ->
  return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

descending = (a, b) ->
  return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN


sortFns = {
  natural: ({prop, direction}) ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then ascending else descending
    return (a, b) -> cmpFn(a.prop[prop], b.prop[prop])

  caseInsensetive: ({prop, direction}) ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then ascending else descending
    return (a, b) -> cmpFn(String(a.prop[prop]).toLowerCase(), String(b.prop[prop]).toLowerCase())
}


simpleDriver = (data, query) ->
  rootSegment = {
    _raw: data
    prop: {}
  }
  segmentGroups = [[rootSegment]]

  for cmd in query
    switch cmd.operation
      when 'split'
        propName = cmd.prop
        throw new Error("'prop' not defined in apply") unless propName
        splitFn = splitFns[cmd.bucket]
        throw new Error("No such bucket `#{cmd.bucket}` in split") unless splitFn
        bucketFn = splitFn(cmd)
        segmentGroups = flatten(segmentGroups).map (segment) ->
          keys = []
          buckets = {}
          bucketValue = {}
          for d in segment._raw
            key = bucketFn(d)
            throw new Error("Bucket returned undefined") unless key?
            if not buckets[key]
              keys.push(key)
              buckets[key] = []
              bucketValue[key] = key # Key might not be a string
            buckets[key].push(d)

          segment.splits = keys.map((key) ->
            prop = {}
            prop[propName] = bucketValue[key]
            return {
              _raw: buckets[key]
              prop
            }
          )
          delete segment._raw
          return segment.splits

      when 'apply'
        propName = cmd.prop
        throw new Error("'prop' not defined in apply") unless propName
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
          for segmentGroup in segmentGroups
            segmentGroup.splice(limit, segmentGroup.length - limit)

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  # Cleanup _raw data on last segment
  for segmentGroup in segmentGroups
    for segment in segmentGroup
      delete segment._raw

  return rootSegment


simple = (data) -> (query, callback) ->
  try
    result = simpleDriver(data, query)
  catch e
    callback({ message: e.message, stack: e.stack }); return

  callback(null, result)
  return

# Add where needed
if facet?.driver?
  facet.driver.simple = simple

if typeof module isnt 'undefined' and typeof exports isnt 'undefined'
  module.exports = simple

