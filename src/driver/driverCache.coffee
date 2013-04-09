`(typeof window === 'undefined' ? {} : window)['driverCache'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------

class DriverCache
  constructor: (@timeAttribute, @timeName) ->
    @hashmap = {}
    # { key: filter (non-time filter) + gran,
    #   value: { key: timestamp,
    #            value: { key: metric,
    #                     value: value } } }

  get: (query) ->
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
    hash = @_generateHash(query)
    cachedData = {}
    hashValue = @hashmap[hash] or {}
    timestamps = @_timeCalculate(query)
    for timestamp in timestamps
      cachedData[timestamp] = hashValue?[timestamp]
    return cachedData

  put: (query, root) ->
    hash = @_generateHash(query)
    @hashmap[hash] ?= {} # ToDo: enforce cache size limits
    hashValue = @hashmap[hash]
    for split in root.splits
      timerange = split.prop[@timeName]
      tempPiece = hashValue[timerange] or {}
      for k, v of split.prop
        continue unless split.prop.hasOwnProperty(k)
        continue if k is @timeName
        tempPiece[k] = v
      hashValue[timerange] = tempPiece
    return

  _getFilter: (query) ->
    return query.filter(({operation}) -> return operation is 'filter')[0]

  _getSplit: (query) ->
    return query.filter(({operation}) -> return operation is 'split')[0]

  _generateHash: (query) ->
    # Get Filter and Split
    {filter, timeFilter} = @_separateTimeFilter(@_getFilter(query))
    split = @_getSplit(query)
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

  _collectApply: (query) ->
    splitLocation = query.map(({operation}) -> return operation is 'split').indexOf(true)
    return query.filter((command, i) -> return i > splitLocation) # DONT DO SPLICE. It will change query

  _timeCalculate: (query) ->
    split = @_getSplit(query)
    {timeFilter} = @_separateTimeFilter(@_getFilter(query))
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
  cache = new DriverCache(timeAttribute)

  # ToDo : no _s
  _fillTree = (root, cachedData, query) -> # Fill in the missing piece
    splitOp = query.filter(({operation}) -> return operation is 'split')[0]
    splitOpName = splitOp.name
    splitLocation = query.indexOf(splitOp)
    applysAfterSplit = query.filter((command, i) -> return i > splitLocation and command.operation is 'apply')
                            .map((command) -> return command.name)
    # Handle 1 split for now
    for split in root.splits
      timestamp = split.prop[timeName]
      for apply in applysAfterSplit
        split.prop[apply] ?= cachedData[timestamp]?[apply]
    return root

  _getUnknownQuery = (query, cachedData) ->
    # Look at cache to see what we know
    splitLocation = query.map(({operation}) -> return operation is 'split').indexOf(true)
    # What we need from data
    applysAfterSplit = query.filter((command, i) -> return i > splitLocation and command.operation is 'apply')
                            .map((command) -> return command.name)
    # Go through cachedData. See if we have need data for all time stamps

    unknown = {}
    for k, v of cachedData
      unless v?
        for apply in applysAfterSplit
          unknown[apply] = true
        continue
      for apply in applysAfterSplit
        if not v[apply]?
          unknown[apply] = true

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

    cachedData = cache.get(query)
    unknownQuery = _getUnknownQuery(query, cachedData)
    driver unknownQuery, (err, root) ->
      if err?
        callback(err, null)
        return
      cache.put(query, root)
      callback(null, _fillTree(root, cachedData, query))
      return
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
