`(typeof window === 'undefined' ? {} : window)['driverCache'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
driverUtil = require('./driverUtil')

class DriverCache
  constructor: (@timeAttribute, @timeName) ->
    @hashmap = {}
    # { key: filter (non-time filter) + gran,
    #   value: { key: timestamp,
    #            value: { key: metric,
    #                     value: value } } }

  get: (condensedQuery) ->
    # Return format:
    # {
    #   <timestamp>: {
    #     <metric>: <value>
    #     <metric>: <value>
    #   }
    #   <timestamp>: {
    #     <metric>: <value>
    #     <metric>: <value>
    #   }
    # }
    hash = @_generateHash(condensedQuery)
    cachedData = {}
    hashValue = @hashmap[hash] or {}
    timeranges = @_timeCalculate(condensedQuery)
    for timerange in timeranges
      cachedData[timerange] = hashValue?[timerange]
    return cachedData

  put: (condensedQuery, root) ->
    hash = @_generateHash(condensedQuery)
    @hashmap[hash] ?= {} # ToDo: enforce cache size limits
    hashValue = @hashmap[hash]
    for split in root.splits
      timerange = split.prop[@timeName]
      tempPiece = hashValue[timerange] or {}
      for k, v of split.prop
        # continue unless split.prop.hasOwnProperty(k)
        # continue if k is @timeName
        tempPiece[k] = v
      hashValue[timerange] = tempPiece
    return

  _generateHash: (condensedQuery) ->
    # Get Filter and Split
    {filter, timeFilter} = @_separateTimeFilter(condensedQuery[0].filter)
    split = condensedQuery[1].split
    return @_filterToHash(filter) + '&' + @_splitToHash(split)

  _filterToHash: (filter) ->
    return '' unless filter?
    hash = []
    if filter.filters?
      for subFilter in filter.filters
        hash.push @_filterToHash(filter)
      return hash.sort().join(filter.type)
    else
      for k, v of filter
        hash.push(k + ":" + v)
    return hash.sort().join('|')

  _splitToHash: (split) ->
    hash = []
    for k, v of split
      hash.push(k + ":" + v)

    return hash.sort().join('|')

  _separateTimeFilter: (filter) ->
    if filter.filters?
      timeFilter = filter.filters.filter((({attribute}) -> attribute is @timeAttribute), this)[0]
      filtersWithoutTime = filter.filters.filter((({attribute}) -> attribute isnt @timeAttribute), this)
      if filtersWithoutTime.length is 1
        return {
          filter: filtersWithoutTime[0]
          timeFilter
        }
      else
        # ToDo: make new And filter
        filter.filters = filtersWithoutTime
        return {
          filter
          timeFilter
        }
    else # Only time filter exists
      return {
        filter: null
        timeFilter: filter
      }

  _timeCalculate: (condensedQuery) ->
    split = condensedQuery[1].split
    {timeFilter} = @_separateTimeFilter(condensedQuery[0].filter)
    timestamps = []
    timestamp = new Date(timeFilter.range[0])
    end = new Date(timeFilter.range[1])
    if split.bucket is 'timeDuration'
      duration = split.duration
      while new Date(timestamp.valueOf() + duration) <= end
        timestamps.push([timestamp, new Date(timestamp.valueOf() + duration)])
        timestamp = new Date(timestamp.valueOf() + duration)
    else if split.bucket is 'timePeriod'
      periodMap = {
        'PT1S': 1000
        'PT1M': 60 * 1000
        'PT1H': 60 * 60 * 1000
        'P1D' : 24 * 60 * 60 * 1000
      }
      period = periodMap[split.period]
      while new Date(timestamp.valueOf() + period) <= end
        timestamps.push([timestamp, new Date(timestamp.valueOf() + period)])
        timestamp = new Date(timestamp.valueOf() + period)
    else
      throw new Error("unknown time bucket")
    return timestamps

module.exports = ({driver, timeAttribute, timeName}) ->
  cache = new DriverCache(timeAttribute, timeName)

  fillTree = (root, cachedData, condensedQuery) -> # Fill in the missing piece
    splitOp = condensedQuery[1].split
    splitOpName = splitOp.name
    applysAfterSplit = condensedQuery[1].applies.map((command) -> return command.name)

    # Handle 1 split for now
    for split in root.splits
      timestamp = split.prop[timeName]
      for apply in applysAfterSplit
        split.prop[apply] ?= cachedData[timestamp]?[apply]
    return root

  createTree = (cachedData, condensedQuery) ->
    splitOp = condensedQuery[1].split
    splitOpName = splitOp.name
    applysAfterSplit = condensedQuery[1].applies.map((command) -> return command.name)
    # Handle 1 split for now
    root = {
      prop: {}
    }
    root.splits = splits = []
    for timerange, value of cachedData
      prop = {}
      prop[timeName] = value[timeName]
      for apply in applysAfterSplit
        prop[apply] = value[apply]
      splits.push {
        prop
      }

    combineOp = condensedQuery[1].combine
    if combineOp?.sort?
      sortProp = combineOp.sort.prop
      if sortProp is timeName
        if combineOp.sort.direction is 'descending'
          splits.sort((a, b) -> return b.prop[sortProp][0] - a.prop[sortProp][0])
        else if 'ascending'
          splits.sort((a, b) -> return a.prop[sortProp][0] - b.prop[sortProp][0])
      else
        if combineOp.sort.direction is 'descending'
          splits.sort((a, b) -> return b.prop[sortProp] - a.prop[sortProp])
        else if 'ascending'
          splits.sort((a, b) -> return a.prop[sortProp] - b.prop[sortProp])
      if combineOp.limit?
        splits.splice(combineOp.limit)
    return root

  getUnknownQuery = (query, cachedData, condensedQuery) ->
    # Look at cache to see what we know
    splitLocation = query.map(({operation}) -> return operation is 'split').indexOf(true)
    # What we need from data
    applysAfterSplit = condensedQuery[1].applies.map((apply) -> return apply.name)
    # Go through cachedData. See if we have need data for all time stamps

    unknown = {}
    unknownExists = false

    for k, v of cachedData
      unless v?
        for apply in applysAfterSplit
          unknown[apply] = true
          unknownExists = true
        continue
      for apply in applysAfterSplit
        if not v[apply]?
          unknown[apply] = true
          unknownExists = true

    return null unless unknownExists
    return query.filter((command, i) ->
        return true if i <= splitLocation
        if (command.operation is 'apply' and unknown[command.name]) or command.operation isnt 'apply'
          return true
        return false
      )

  return (query, callback) ->
    if query.filter(({operation}) -> return operation is 'filter').length is 0
      driver query, callback
      return
    # If there is more than one split, don't use cache
    if query.filter(({operation}) -> return operation is 'split').length isnt 1
      driver query, callback
      return
    # If there is a split not for time, reject
    if query.filter(({operation, attribute}) -> return operation is 'split' and attribute isnt timeAttribute).length > 0
      driver query, callback
      return

    condensedQuery = driverUtil.condenseQuery(query)

    cachedData = cache.get(condensedQuery)
    unknownQuery = getUnknownQuery(query, cachedData, condensedQuery)

    if unknownQuery?
      driver unknownQuery, (err, root) ->
        if err?
          callback(err, null)
          return
        cache.put(condensedQuery, root)
        callback(null, fillTree(root, cachedData, condensedQuery))
    else
      callback(null, createTree(cachedData, condensedQuery))
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
