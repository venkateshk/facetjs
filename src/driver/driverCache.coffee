`(typeof window === 'undefined' ? {} : window)['driverCache'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
driverUtil = require('./driverUtil')

filterToHash = (filter) ->
  return '' unless filter?
  hash = []
  if filter.filters?
    for subFilter in filter.filters
      hash.push filterToHash(subFilter)
    return hash.sort().join(filter.type)
  else
    for k, v of filter
      hash.push(k + ":" + v)
  return hash.sort().join('|')

splitToHash = (split) ->
  hash = []
  for k, v of split
    continue if k is 'name'
    hash.push(k + ":" + v)

  return hash.sort().join('|')

generateHash = (condensedQuery) ->
  # Get Filter and Split
  split = condensedQuery[1].split
  filter = condensedQuery[0].filter
  return filterToHash(filter) + '&' + splitToHash(split)

separateTimeFilter = (filter) ->
  if filter.filters?
    timeFilter = filter.filters.filter((({type}) -> type is 'within'), this)[0]
    filtersWithoutTime = filter.filters.filter((({type}) -> type is 'within'), this)
    if filtersWithoutTime.length is 1
      return {
        filter: filtersWithoutTime[0]
        timeFilter
      }
    else
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


class FilterCache
  # { key: filter,
  #   value: { key: metric,
  #            value: value } }
  constructor: ->
    @hashmap = {}

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
    splitOpName = condensedQuery[1].split.name
    ret = {}
    for value in values
      newFilter = @_addToFilter(condensedQuery, value)
      ret[value] = @hashmap[filterToHash(newFilter)]
      if ret[value]?
        ret[value][splitOpName] = value

    return ret

  put: (condensedQuery, root) ->
    filter = condensedQuery[0].filter
    hashValue = @hashmap[filterToHash(filter)] ?= {}
    for k, v of root.prop
      hashValue[k] = v

    for split in root.splits
      newFilter = @_addToFilter(condensedQuery, split.prop[condensedQuery[1].split.name])
      hashValue = @hashmap[filterToHash(newFilter)] ?= {}
      for k, v of split.prop
        hashValue[k] = v

    return

  _addToFilter: (condensedQuery, value) ->
    oldFilter = condensedQuery[0].filter
    splitOp = condensedQuery[1].split

    if splitOp.bucket in ['timePeriod', 'timeDuration']
      { filter: oldFilter } = separateTimeFilter(oldFilter)
      newFilterPiece = {
        attribute: splitOp.attribute
        type: 'within'
        value
      }
    else
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



class SplitCache
  # { key: filter,
  #   value: { key: split,
  #            value: [list of dimension values] } }
  constructor: ->
    @hashmap = {}

  get: (condensedQuery) ->
    # Return format:
    # [
    # <value>
    # <value>
    # <value>
    # ]
    if condensedQuery[1].split.bucket in ['timePeriod', 'timeDuration']
      return @_timeCalculate(condensedQuery)

    return @hashmap[generateHash(condensedQuery)]

  put: (condensedQuery, root) ->
    hash = generateHash(condensedQuery)
    splitOpName = condensedQuery[1].split.name
    hashValue = []
    for split in root.splits
      hashValue.push split.prop[splitOpName]
    @hashmap[hash] = hashValue
    return

  _timeCalculate: (condensedQuery) ->
    split = condensedQuery[1].split
    {timeFilter} = separateTimeFilter(condensedQuery[0].filter)
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


module.exports = ({driver, queryGetter, querySetter}) ->
  splitCache = new SplitCache()
  filterCache = new FilterCache()

  querySetter ?= (async, query) -> return
  queryGetter ?= (async) -> return async

  if (queryGetter? and not querySetter?) or (not queryGetter? and querySetter?)
    throw new Error("Both querySetter and queryGetter must be supplied")

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
      if combineOp.sort.direction is 'descending'
        splits.sort((a, b) ->
          if a.prop[sortProp][0]?
            return b.prop[sortProp][0] - a.prop[sortProp][0]
          return b.prop[sortProp] - a.prop[sortProp])
      else if 'ascending'
        splits.sort((a, b) ->
          if a.prop[sortProp][0]?
            return a.prop[sortProp][0] - b.prop[sortProp][0]
          return a.prop[sortProp] - b.prop[sortProp])

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

    if condensedQuery[1].combine?.sort?
      unknown[condensedQuery[1].combine.sort.prop] = true

    return query.filter((command, i) ->
        return true if i <= splitLocation
        if (command.operation is 'apply' and unknown[command.name]) or command.operation isnt 'apply'
          return true
        return false
      )

  return (async, callback) ->
    query = queryGetter(async)
    if query.filter(({operation}) -> return operation is 'filter').length is 0
      driver async, callback
      return
    # If there is more than one split, don't use cache
    if query.filter(({operation}) -> return operation is 'split').length isnt 1
      driver async, callback
      return

    condensedQuery = driverUtil.condenseQuery(query)

    # If there is a split for contnuous dimension, don't use cache
    if condensedQuery[1].split.bucket is 'continuous'
      driver async, callback
      return

    cachedTopN = splitCache.get(condensedQuery)
    if cachedTopN?
      cachedData = filterCache.get(condensedQuery, cachedTopN)
      unknownQuery = getUnknownQuery(query, cachedData, condensedQuery)
    else
      unknownQuery = query

    if unknownQuery?
      querySetter(async, unknownQuery)
      driver async, (err, root) ->
        if err?
          callback(err, null)
          return

        splitCache.put(condensedQuery, root)
        filterCache.put(condensedQuery, root)
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
