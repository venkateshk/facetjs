`(typeof window === 'undefined' ? {} : window)['generalCache'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
driverUtil = require('./driverUtil')
{ FacetQuery, AndFilter, TrueFilter, FacetFilter, FacetSplit, FacetCombine } = require('./query')

moveTimestamp = (timestamp, period, timezone) ->
  newTimestamp = new Date(timestamp)

  switch period
    when 'PT1S'
      newTimestamp.setUTCSeconds(newTimestamp.getUTCSeconds() + 1)
    when 'PT1M'
      newTimestamp.setUTCMinutes(newTimestamp.getUTCMinutes() + 1)
    when 'PT1H'
      newTimestamp.setUTCHours(newTimestamp.getUTCHours() + 1)
    when 'P1D'
      newTimestamp = driverUtil.convertToTimezoneJS(timestamp, timezone)
      prevDate = newTimestamp.getDate()
      newTimestamp.setDate(newTimestamp.getDate() + 1)

      if newTimestamp.getHours() < 2
        newTimestamp.setHours(0)
      else
        newTimestamp.setHours(24)
    else
      throw new Error("time period not supported by driver")

  return newTimestamp


filterToHashHelper = (filter) ->
  return switch filter.type
    when 'true'     then "T"
    when 'false'    then "F"
    when 'is'       then "IS:#{filter.attribute}:#{filter.value}"
    when 'in'       then "IN:#{filter.attribute}:#{filter.values.join(';')}"
    when 'contains' then "C:#{filter.attribute}:#{filter.value}"
    when 'match'    then "F:#{filter.attribute}:#{filter.expression}"
    when 'within'   then "W:#{filter.attribute}:#{filter.range[0].valueOf()}:#{filter.range[1].valueOf()}"
    when 'not'      then "N(#{filterToHashHelper(filter.filter)})"
    when 'and'      then "A(#{filter.filters.map(filterToHashHelper).join(')(')})"
    when 'or'       then "O(#{filter.filters.map(filterToHashHelper).join(')(')})"
    else throw new Error("filter type unsupported by driver")

filterToHash = (filter) ->
  return filterToHashHelper(filter.simplify())

splitToHash = (split) ->
  hash = []
  for own k, v of split
    continue if k in ['name', 'segmentFilter']
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

andFilters = (filter1, filter2) ->
  return new AndFilter([filter1, filter2]).simplify()

class FilterCache
  # { key: filter,
  #   value: { key: metric,
  #            value: value } }
  constructor: (@timeAttribute) ->
    @hashmap = {}

  get: (filter) ->
    # {
    #   <attribute>: <value>
    #   <attribute>: <value>
    # }
    return @hashmap[filterToHash(filter)]

  put: (filter, condensedQuery, root) -> # Recursively deconstruct root and add to cache
    @_filterPutHelper(condensedQuery, root, filter, 0)
    return

  _filterPutHelper: (condensedQuery, node, filter, level) ->
    return unless node.prop?

    hashValue = @hashmap[filterToHash(filter)] ?= {}
    applies = condensedQuery[level].applies
    for apply in applies
      hashValue[apply.name] = node.prop[apply.name] ? hashValue[apply.name]

    if node.splits?
      splitOp = condensedQuery[level + 1].split
      for split in node.splits
        newFilter = andFilters(filter, splitOp.getFilterFor(split.prop))
        @_filterPutHelper(condensedQuery, split, newFilter, level + 1)
    return


class SplitCache
  # { key: filter,
  #   value: { key: split,
  #            value: [list of dimension values] } }
  constructor: (@timeAttribute) ->
    @hashmap = {}

  get: (filter, splitOp, combineOp) ->
    # Return format:
    # [
    #   <value>
    #   <value>
    #   <value>
    # ]
    if splitOp.bucket in ['timePeriod', 'timeDuration'] and splitOp.name is combineOp.sort?.prop
      return @_timeCalculate(filter, splitOp, combineOp)
    else
      hash = generateHash(filter, splitOp, combineOp)
      return @hashmap[hash]

  put: (filter, condensedQuery, root) -> # Recursively deconstruct root and add to cache
    @_splitPutHelper(filter, condensedQuery, root, 0)
    return

  _splitPutHelper: (filter, condensedQuery, node, level) ->
    return unless node.splits?

    splitOp = condensedQuery[level + 1].split
    combineOp = condensedQuery[level + 1].combine
    splitOpName = splitOp.name
    splitValues = node.splits.map((node) -> node.prop[splitOpName])
    hash = generateHash(filter, splitOp, combineOp)
    @hashmap[hash] = splitValues

    if condensedQuery[level + 2]?
      for split in node.splits
        newFilter = andFilters(filter, splitOp.getFilterFor(split.prop))
        @_splitPutHelper(newFilter, condensedQuery, split, level + 1)
    return

  _timeCalculate: (filter, splitOp, combineOp) ->
    separatedFilters = filter.extractFilterByAttribute(@timeAttribute)
    timeFilter = separatedFilters[1]
    timezone = splitOp.timezone or 'Etc/UTC'
    timestamps = []
    [timestamp, end] = timeFilter.range.map((timestamp) -> driverUtil.convertToTimezoneJS(timestamp, timezone))
    if splitOp.bucket is 'timeDuration'
      duration = splitOp.duration
      while true
        newTimestamp = new Date(timestamp.valueOf() + duration)
        break if newTimestamp > end
        timestamps.push([new Date(timestamp), new Date(newTimestamp)])
        timestamp = newTimestamp

    else if splitOp.bucket is 'timePeriod'
      while true
        newTimestamp = moveTimestamp(timestamp, splitOp.period, timezone)
        break if newTimestamp > end
        timestamps.push([new Date(timestamp), new Date(newTimestamp)])
        timestamp = newTimestamp
    else
      throw new Error("unknown time bucket")

    return timestamps


module.exports = ({driver, timeAttribute}) ->
  timeAttribute ?= 'timestamp'
  splitCache = new SplitCache(timeAttribute)
  filterCache = new FilterCache(timeAttribute)

  checkDeep = (node, currentLevel, targetLevel, name, bucketFilter) ->
    if currentLevel is targetLevel
      return node.prop[name]?

    if filteredSplitValue = node.prop[bucketFilter?.prop]
      if filteredSplitValue in bucketFilter?.values
        if node.splits?
          return node.splits.every((split) -> return checkDeep(split, currentLevel + 1, targetLevel, name))
        return false
      else
        return true

    if node.splits?
      return node.splits.every((split) -> return checkDeep(split, currentLevel + 1, targetLevel, name, bucketFilter))
    return false

  bucketFilterValueCheck = (node, currentLevel, targetLevel, bucketFilter) ->
    if currentLevel is targetLevel
      return bucketFilter.values unless node.splits?
      currentSplits = node.splits.filter(({splits}) -> return splits?).map((split) -> split.prop[bucketFilter.prop])
      return bucketFilter.values.filter((value) -> value not in currentSplits)

    if node.splits?
      return node.splits.map((split) -> return bucketFilterValueCheck(split, currentLevel + 1, targetLevel, bucketFilter))
              .reduce(((prevValue, currValue) -> prevValue.push currValue; return prevValue), [])

    return bucketFilter.values

  getUnknownQuery = (filter, query, root, condensedQuery) ->
    return query unless root?
    unknownQuery = []
    added = false

    if filter not instanceof TrueFilter
      filterSpec = filter.valueOf()
      filterSpec.operation = 'filter'
      unknownQuery.push filterSpec

    for condensedCommand, i in condensedQuery
      if condensedCommand.split
        newSplit = condensedCommand.split.valueOf()
        newSplit.operation = 'split'
        if condensedCommand.split.segmentFilter?
          newValues = bucketFilterValueCheck(root, 0, i - 2, condensedCommand.split.segmentFilter)
          newSplit.segmentFilter.values = newValues
          if newValues.length > 0
            added = true
        unknownQuery.push newSplit

      if condensedCommand.combine
        mustApply = condensedCommand.combine.sort.prop

      for apply in condensedCommand.applies
        exists = checkDeep(root, 0, i, apply.name, condensedCommand.split?.segmentFilter)
        if not exists
          added = true

        if apply.name is mustApply or not exists
          applySpec = apply.valueOf()
          applySpec.operation = 'apply'
          unknownQuery.push applySpec

      if condensedCommand.combine
        combineSpec = condensedCommand.combine.valueOf()
        combineSpec.operation = 'combine'
        unknownQuery.push combineSpec

    if added
      return new FacetQuery(unknownQuery)

    return null

  getKnownTreeHelper = (filter, condensedQuery, level, upperSplitValue) ->
    applies = condensedQuery[level].applies
    splitOp = condensedQuery[level + 1]?.split
    combineOp = condensedQuery[level + 1]?.combine
    filterCacheResult = filterCache.get(filter)

    prop = {}
    if filterCacheResult?
      for apply in applies
        prop[apply.name] = filterCacheResult[apply.name]

    if not splitOp? # end case
      return {
        prop
      }

    cachedValues = splitCache.get(filter, splitOp, combineOp)

    if not cachedValues?
      return {
        prop
      }

    bucketFilter = splitOp.bucketFilter
    if bucketFilter?
      if upperSplitValue not in bucketFilter.values
        return {
          prop
        }

    splits = []

    for value in cachedValues
      fakeProp = {}
      fakeProp[splitOp.name] = value
      newFilter = andFilters(filter, splitOp.getFilterFor(fakeProp))
      ret = getKnownTreeHelper(newFilter, condensedQuery, level + 1, value)
      ret.prop[splitOp.name] = value
      splits.push ret

    if combineOp?.sort?
      sortProp = combineOp.sort.prop
      if combineOp.sort.direction is 'descending'
        if splits.every((split) -> split.prop[sortProp]?[0]?)
          sortFn = (a, b) -> return b.prop[sortProp][0] - a.prop[sortProp][0]
        else
          sortFn = (a, b) -> return b.prop[sortProp] - a.prop[sortProp]
      else if combineOp.sort.direction is 'ascending'
        if splits.every((split) -> split.prop[sortProp]?[0]?)
          sortFn = (a, b) -> return a.prop[sortProp][0] - b.prop[sortProp][0]
        else
          sortFn = (a, b) -> return a.prop[sortProp] - b.prop[sortProp]

      notPartSplits = splits.filter((split) -> not split.prop[sortProp]?)
      splits = splits.filter((split) -> split.prop[sortProp]?)
      splits.sort(sortFn)
      splits = splits.concat(notPartSplits)

      if combineOp.limit?
        splits.splice(combineOp.limit)

    return {
      prop
      splits
    }

  getKnownTree = (filter, condensedQuery) ->
    throw new Error("must have filter") unless filter
    return getKnownTreeHelper(filter, condensedQuery, 0)

  convertEmptyTreeToEmptyObject = (tree) ->
    propKeys = (key for key, value of tree.prop)
    return {} if (propKeys.length is 0 and not tree.splits?)
    return tree

  return (request, callback) ->
    throw new Error("request not supplied") unless request
    {context, query} = request

    if query not instanceof FacetQuery
      callback(new Error("query must be a FacetQuery"))
      return

    filter = query.getFilter()
    condensedQuery = query.getGroups()

    # If there is a split for continuous dimension, don't use cache. Doable. but not now
    datasets = query.getDatasets()
    if condensedQuery[1]?.split?.bucket in ['continuous', 'tuple'] or datasets.length > 1 or datasets[0] isnt 'main'
      return driver({query}, callback)

    root = getKnownTree(filter, condensedQuery)
    unknownQuery = getUnknownQuery(filter, query, root, condensedQuery)
    if not unknownQuery
      callback(null, root)
      return

    return driver {context, query: unknownQuery}, (err, root) ->
      if err?
        callback(err, null)
        return

      splitCache.put(filter, condensedQuery, root)
      filterCache.put(filter, condensedQuery, root)
      knownTree = convertEmptyTreeToEmptyObject(getKnownTree(filter, condensedQuery))
      callback(null, knownTree)
    return



# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath, altPath) {
    if (altPath) return window[altPath];
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
