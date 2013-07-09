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
  for own k, v of split
    continue if k is 'name'
    hash.push(k + ":" + v)

  return hash.sort().join('|')

combineToHash = (combine) ->
  hash = []
  for own k, v of combine
    hash.push(k + ":" + JSON.stringify(v))

  return hash.sort().join('|')

generateHash = (filter, splitOp, combineOp) ->
  # Get Filter and Split
  return filterToHash(filter) + '&' + splitToHash(splitOp) + '&' + combineToHash(combineOp)

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
          type: 'and'
          operation: 'filter'
          filters: filtersWithoutTime
        }
        timeFilter
      }
  else # Only time filter exists
    return {
      filter: null
      timeFilter: filter
    }

addToFilter = (filter, newFilterPiece) ->
  if filter?
    if newFilterPiece.type is 'within'
      { filter, timeFilter } = separateTimeFilter(filter)

    return {
      type: 'and'
      operation: 'filter'
      filters: [newFilterPiece, filter]
    }
  return newFilterPiece

createFilter = (value, splitOp) ->
  if splitOp.bucket in ['timePeriod', 'timeDuration']
    newFilterPiece = {
      attribute: splitOp.attribute
      operation: 'filter'
      type: 'within'
      value
    }
  else
    newFilterPiece = {
      attribute: splitOp.attribute
      operation: 'filter'
      type: 'is'
      value
    }
  return newFilterPiece

class FilterCache
  # { key: filter,
  #   value: { key: metric,
  #            value: value } }
  constructor: ->
    @hashmap = {}

  get: (filter) ->
    #   {
    #     <attribute>: <value>
    #     <attribute>: <value>
    #   }
    return @hashmap[filterToHash(filter)]

  put: (condensedQuery, root) -> # Recursively deconstruct root and add to cache
    @_filterPutHelper(condensedQuery, root, condensedQuery[0].filter, 0)
    return

  _filterPutHelper: (condensedQuery, root, filter, level) ->
    hashValue = @hashmap[filterToHash(filter)] ?= {}
    applies = condensedQuery[level].applies
    for apply in applies
      hashValue[apply.name] = root.prop[apply.name] or hashValue[apply.name]

    if root.splits?
      splitOp = condensedQuery[level + 1].split
      for split in root.splits
        @_filterPutHelper(condensedQuery, split, addToFilter(filter, createFilter(split.prop[splitOp.name], splitOp)), level + 1)
    return


class SplitCache
  # { key: filter,
  #   value: { key: split,
  #            value: [list of dimension values] } }
  constructor: ->
    @hashmap = {}

  get: (filter, splitOp, combineOp) ->
    # Return format:
    # [
    # <value>
    # <value>
    # <value>
    # ]
    if splitOp.bucket in ['timePeriod', 'timeDuration']
      return @_timeCalculate(filter, splitOp)
    return @hashmap[generateHash(filter, splitOp, combineOp)]

  put: (condensedQuery, root) -> # Recursively deconstruct root and add to cache
    @_splitPutHelper(condensedQuery, root, condensedQuery[0].filter, 0)
    return

  _splitPutHelper: (condensedQuery, node, filter, level) ->
    return unless node.splits?

    splitOp = condensedQuery[level + 1].split
    combineOp = condensedQuery[level + 1].combine
    splitOpName = splitOp.name
    splitValues = node.splits.map((node) -> return node.prop[splitOpName])
    @hashmap[generateHash(filter, splitOp, combineOp)] = splitValues

    if condensedQuery[level + 2]?
      for split in node.splits
        @_splitPutHelper(condensedQuery, split, addToFilter(filter, createFilter(split.prop[splitOpName], splitOp)), level + 1)
    return

  _timeCalculate: (filter, splitOp) ->
    {timeFilter} = separateTimeFilter(filter)
    timestamps = []
    timestamp = new Date(timeFilter.range[0])
    end = new Date(timeFilter.range[1])
    if splitOp.bucket is 'timeDuration'
      duration = splitOp.duration
      while new Date(timestamp.valueOf() + duration) <= end
        timestamps.push([timestamp, new Date(timestamp.valueOf() + duration)])
        timestamp = new Date(timestamp.valueOf() + duration)
    else if splitOp.bucket is 'timePeriod'
      periodMap = {
        'PT1S': 1000
        'PT1M': 60 * 1000
        'PT1H': 60 * 60 * 1000
        'P1D' : 24 * 60 * 60 * 1000
      }
      period = periodMap[splitOp.period]
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

  getUnknownQuery = (query, root, condensedQuery) ->
    return query unless root?
    unknownQuery = []
    addAll = false
    currentNode = root

    checkDeep = (node, currentLevel, targetLevel, name) ->
      if currentLevel is targetLevel
        return node.prop[name]?

      if node.splits?
        return node.splits.every((split) -> return checkDeep(split, currentLevel + 1, targetLevel, name))

      return false

    added = false

    for condensedCommand, i in condensedQuery
      if condensedCommand.filter?
        unknownQuery.push condensedCommand.filter

      if condensedCommand.split?
        unknownQuery.push condensedCommand.split

      if condensedCommand.combine?
        mustApply = condensedCommand.combine.sort.prop

      if condensedCommand.applies?
        for apply in condensedCommand.applies
          exists = checkDeep(root, 0, i, apply.name)
          if not exists
            added = true

          if (apply.name is mustApply) or (not exists)
            unknownQuery.push apply


      if condensedCommand.combine?
        unknownQuery.push condensedCommand.combine

    if added
      return unknownQuery

    return null

  getKnownTreeHelper = (condensedQuery, filter, level) ->
    applies = condensedQuery[level].applies
    splitOp = condensedQuery[level + 1]?.split
    combineOp = condensedQuery[level + 1]?.combine
    filterCacheResult = filterCache.get(filter)

    prop = {}
    for apply in applies
      prop[apply.name] = filterCacheResult?[apply.name]

    if not splitOp? # end case
      return {
        prop
      }

    cachedValues = splitCache.get(filter, splitOp, combineOp)

    if not cachedValues?
      return {
        prop
      }

    splits = []

    for value in cachedValues
      ret = getKnownTreeHelper(condensedQuery, addToFilter(filter, createFilter(value, splitOp)), level + 1)
      # return null unless ret?
      ret.prop[splitOp.name] = value
      splits.push ret

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

    return {
      prop
      splits
    }

  getKnownTree = (condensedQuery) ->
    return getKnownTreeHelper(condensedQuery, condensedQuery[0].filter, 0)

  return (async, callback) ->
    query = queryGetter(async)

    try
      condensedQuery = driverUtil.condenseQuery(query)
    catch e
      callback(e)
      return

    # If there is a split for contnuous dimension, don't use cache. Doable. but not now
    if condensedQuery[1]?.split?.bucket in ['continuous', 'tuple']
      return driver async, callback

    root = getKnownTree(condensedQuery)
    unknownQuery = getUnknownQuery(query, root, condensedQuery)

    if not unknownQuery?
      callback(null, root)
      return

    querySetter(async, unknownQuery)
    return driver async, (err, root) ->
      if err?
        callback(err, null)
        return

      splitCache.put(condensedQuery, root)
      filterCache.put(condensedQuery, root)
      callback(null, getKnownTree(condensedQuery))
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
