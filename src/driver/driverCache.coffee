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
    #     <attribute>: <value>
    #     <attribute>: <value>
    #   }
    #   <timestamp>: {
    #     <attribute>: <value>
    #     <attribute>: <value>
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
        hash.push @_filterToHash(subFilter)
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
          filter: {
            operation: 'filter'
            type: 'and'
            filters: filtersWithoutTime
          }
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

class FilterCache
  constructor: ->
    @hashmap = {}
    # { key: filter,
    #   value: { key: metric,
    #            value: value } }

  get: (condensedQuery, values) ->
    # Return format:
    # [
    #   {
    #     <attribute>: <value>
    #     <attribute>: <value>
    #   }
    #   {
    #     <attribute>: <value>
    #     <attribute>: <value>
    #   }
    # ]
    filter = condensedQuery[0].filter
    splitOp = condensedQuery[1].split
    splitOpName = splitOp.name
    ret = {}
    for value in values
      newFilter = @_addToFilter(condensedQuery, value)
      ret[value] = @hashmap[@_filterToHash(newFilter)] or null

    for k, v of ret
      v[splitOpName] = k

    return ret

  put: (condensedQuery, root) ->
    filter = condensedQuery[0].filter
    hashValue = @hashmap[@_filterToHash(filter)] ?= {}
    for k, v of root.prop
      hashValue[k] = v

    for split in root.splits
      newFilter = @_addToFilter(condensedQuery, split.prop[condensedQuery[1].split.name])
      hashValue = @hashmap[@_filterToHash(newFilter)] ?= {}
      for k, v of split.prop
        hashValue[k] = v

    return

  _addToFilter: (condensedQuery, value) ->
    oldFilter = condensedQuery[0].filter
    splitOp = condensedQuery[1].split

    newFilterPiece = {
      attribute: splitOp.attribute
      type: 'is'
      value
    }

    if oldFilter?
      return {
        type: 'and'
        filters: [].concat([newFilterPiece], oldFilter)
      }
    return newFilterPiece

  _filterToHash: (filter) ->
    return '' unless filter?
    hash = []
    if filter.filters?
      for subFilter in filter.filters
        hash.push @_filterToHash(subFilter)
      return hash.sort().join(filter.type)
    else
      for k, v of filter
        hash.push(k + ":" + v)
    return hash.sort().join('|')


class SplitCache
  constructor: ->
    @hashmap = {}
    # { key: filter,
    #   value: { key: split,
    #            value: [list of dimension values] } }

  get: (condensedQuery) ->
    # Return format:
    # [
    # <value>
    # <value>
    # <value>
    # ]
    return @hashmap[@_generateHash(condensedQuery)]

  put: (condensedQuery, root) ->
    hash = @_generateHash(condensedQuery)
    splitOpName = condensedQuery[1].split.name
    hashValue = []
    for split in root.splits
      hashValue.push split.prop[splitOpName]
    @hashmap[hash] = hashValue
    return

  _generateHash: (condensedQuery) ->
    # Get Filter and Split
    split = condensedQuery[1].split
    filter = condensedQuery[0].filter
    return @_filterToHash(filter) + '&' + @_splitToHash(split)

  _filterToHash: (filter) ->
    return '' unless filter?
    hash = []
    if filter.filters?
      for subFilter in filter.filters
        hash.push @_filterToHash(subFilter)
      return hash.sort().join(filter.type)
    else
      for k, v of filter # TODO: See if we can be brief
        hash.push(k + ":" + v)
    return hash.sort().join('|')

  _splitToHash: (split) ->
    hash = []
    for k, v of split
      hash.push(k + ":" + v)

    return hash.sort().join('|')

module.exports = ({driver, timeAttribute, timeName}) ->
  timeCache = new DriverCache(timeAttribute, timeName)
  splitCache = new SplitCache()
  filterCache = new FilterCache()

  fillTree = (root, cachedData, condensedQuery) -> # Fill in the missing piece
    splitOp = condensedQuery[1].split
    splitOpName = splitOp.name
    applysAfterSplit = condensedQuery[1].applies.map((command) -> return command.name)

    # Handle 1 split for now
    for split in root.splits
      splitName = split.prop[splitOpName]
      for apply in applysAfterSplit
        split.prop[apply] ?= cachedData[splitName]?[apply]
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
    for key, value of cachedData
      prop = {}
      prop[splitOpName] = value[splitOpName]
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
        break
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
    condensedQuery = driverUtil.condenseQuery(query)
    caches = []
    if query.filter(({operation, attribute}) -> return operation is 'split' and attribute isnt timeAttribute).length > 0
      cachedTopN = splitCache.get(condensedQuery)
      if cachedTopN?
        cachedData = filterCache.get(condensedQuery, cachedTopN)
        unknownQuery = getUnknownQuery(query, cachedData, condensedQuery)
      else
        unknownQuery = query
      caches = [splitCache, filterCache]
    else
      cachedData = timeCache.get(condensedQuery)
      unknownQuery = getUnknownQuery(query, cachedData, condensedQuery)
      caches = [timeCache]

    if unknownQuery?
      driver unknownQuery, (err, root) ->
        if err?
          callback(err, null)
          return

        caches.forEach((cache) -> cache.put(condensedQuery, root))
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
