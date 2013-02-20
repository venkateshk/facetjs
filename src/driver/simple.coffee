# Utils

flatten = (ar) -> Array::concat.apply([], ar)

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
  count: -> (ds) -> ds.length

  sum: ({attribute}) -> (ds) -> d3.sum(ds, (d) -> d[attribute])

  average: ({attribute}) -> (ds) -> d3.sum(ds, (d) -> d[attribute]) / ds.length

  min: ({attribute}) -> (ds) -> d3.min(ds, (d) -> d[attribute])

  max: ({attribute}) -> (ds) -> d3.max(ds, (d) -> d[attribute])

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

sortFns = {
  natural: ({prop, direction}) ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then d3.ascending else d3.descending
    return (a, b) -> cmpFn(a.prop[prop], b.prop[prop])

  caseInsensetive: ({prop, direction}) ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then d3.ascending else d3.descending
    return (a, b) -> cmpFn(String(a.prop[prop]).toLowerCase(), String(b.prop[prop]).toLowerCase())
}


simpleDriver = (data, query) ->
  rootSegment = {
    raw: data
    prop: {}
  }
  segmentGroups = [[rootSegment]]

  for cmd in query
    switch cmd.operation
      when 'split'
        propName = cmd.prop
        throw new Error("'prop' not defined in apply") unless propName
        splitFn = splitFns[cmd.bucket](cmd)
        throw new Error("No such bucket `#{cmd.bucket}` in split") unless splitFn
        segmentGroups = flatten(segmentGroups).map (segment) ->
          keys = []
          buckets = {}
          bucketValue = {}
          for d in segment.raw
            key = splitFn(d)
            if not buckets[key]
              keys.push(key)
              buckets[key] = []
              bucketValue[key] = key # Key might not be a string
            buckets[key].push(d)

          segment.splits = keys.map((key) ->
            prop = {}
            prop[propName] = bucketValue[key]
            return {
              raw: buckets[key]
              prop
            }
          )
          delete segment.raw
          return segment.splits

      when 'apply'
        propName = cmd.prop
        throw new Error("'prop' not defined in apply") unless propName
        applyFn = applyFns[cmd.aggregate](cmd)
        throw new Error("No such aggregate `#{cmd.aggregate}` in apply") unless applyFn
        for segmentGroup in segmentGroups
          for segment in segmentGroup
            segment.prop[propName] = applyFn(segment.raw)

      when 'combine'
        if cmd.sort
          for segmentGroup in segmentGroups
            sortFn = sortFns[cmd.sort.compare](cmd.sort)
            throw new Error("No such compare `#{cmd.sort.compare}` in combine.sort") unless sortFn
            for segmentGroup in segmentGroups
              segmentGroup.sort(sortFn)

        if cmd.limit?
          for segmentGroup in segmentGroups
            segmentGroup.splice(limit, segmentGroup.length - limit)

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  # Cleanup raw data on last segment
  for segmentGroup in segmentGroups
    for segment in segmentGroup
      delete segment.raw

  return rootSegment


simple = (data) -> (query, callback) ->
  callback ?= ->
  try
    result = simpleDriver(data, query)
  catch e
    callback(e, null)
    return

  callback(null, result)
  return

# Add where needed
if facet?.driver?
  facet.driver.simple = simple

if exports
  exports = simple

