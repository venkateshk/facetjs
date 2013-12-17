# -----------------------------------------------------
driverUtil = require('../driver/driverUtil')
{ Duration } = require('../driver/chronology')
{ FacetQuery, AndFilter, TrueFilter, FacetFilter, FacetSplit, FacetApply, FacetCombine } = require('../query')


class LRUCache
  constructor: (@hashFn = String, @name = 'cache') ->
    @clear()

  clear: ->
    @store = {}
    @size = 0
    return

  getWithHash: (hash) ->
    return @store[hash] #?.value

  get: (key) ->
    return @getWithHash(@hashFn(key))

  setWithHash: (hash, value) ->
    @size++ unless @store.hasOwnProperty(hash)
    @store[hash] = value
    # {
    #   value
    #   time: Date.now()
    # }
    return

  set: (key, value) ->
    @setWithHash(@hashFn(key), value)
    return

  getOrCreateWithHash: (hash, createFn) ->
    ret = @getWithHash(hash)
    if not ret
      ret = createFn()
      @setWithHash(hash, ret)
    return ret

  getOrCreate: (key, createFn) ->
    return @getOrCreateWithHash(@hashFn(key), createFn)

# -------------------------

# converts a filter to a string
filterToHash = do ->
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
      when 'and'      then "(#{filter.filters.map(filterToHashHelper).join(')^(')})"
      when 'or'       then "(#{filter.filters.map(filterToHashHelper).join(')v(')})"
      else throw new Error("filter type unsupported by driver")

  return (filter) -> filterToHashHelper(filter.simplify())


# converts a single dataset apply to a string
applyToHash = (apply) ->
  if apply.aggregate
    applyStr = switch apply.aggregate
      when 'constant'    then "C:#{apply.value}"
      when 'count'       then "CT"
      when 'sum'         then "SM:#{apply.attribute}"
      when 'average'     then "AV:#{apply.attribute}"
      when 'min'         then "MN:#{apply.attribute}"
      when 'max'         then "MX:#{apply.attribute}"
      when 'uniqueCount' then "UC:#{apply.attribute}"
      when 'quantile'    then "QT:#{apply.attribute}:#{apply.quantile}"
      else throw new Error("apply aggregate unsupported by driver")

    if apply.filter
      applyStr += '/' + filterToHash(apply.filter)

  else if apply.arithmetic
    [op1, op2] = apply.operands
    applyStr = switch apply.arithmetic
      when 'add'      then "#{applyToHash(op1)}+#{applyToHash(op2)}"
      when 'subtract' then "#{applyToHash(op1)}-#{applyToHash(op2)}"
      when 'multiply' then "#{applyToHash(op1)}*#{applyToHash(op2)}"
      when 'divide'   then "#{applyToHash(op1)}/#{applyToHash(op2)}"
      else throw new Error("apply arithmetic unsupported by driver")

  return applyStr


splitToHash = (split) ->
  return switch split.bucket
    when 'identity'   then "ID:#{split.attribute}"
    when 'continuous' then "CT:#{split.attribute}:#{split.offset}:#{split.size}"
    when 'timePeriod' then "TP:#{split.attribute}" # :#{split.period}:#{split.timezone}
    else throw new Error("bucket '#{split.bucket}' unsupported by driver")


filterSplitToHash = (datasetMap, filter, split) ->
  splits = if split.bucket is 'parallel' then split.splits else [split]
  return splits.map((split) ->
    dataset = datasetMap[split.getDataset()]
    andFilter = new AndFilter([dataset.getFilter(), filter])
    extract = andFilter.extractFilterByAttribute(split.attribute)
    return dataset.source + '#' + filterToHash(extract[0]) + '//' + splitToHash(split)
  ).sort().join('*')


appliesToHashes = (appliesByDataset, datasetMap) ->
  applyHashes = []
  for datasetName, applies of appliesByDataset
    for apply in applies
      dataset = datasetMap[datasetName]
      throw new Error("something went wrong") unless dataset

      datasetFilter = dataset.getFilter()
      applyHashes.push({
        name: apply.name
        hash: dataset.source + '#' + applyToHash(apply)
        datasetFilter
        datasetFilterHash: filterToHash(datasetFilter)
      })

  return applyHashes


makeDatasetMap = (query) ->
  datasets = query.getDatasets()
  map = {}
  map[dataset.name] = dataset for dataset in datasets
  return map

getRealSplit = (split) ->
  return if split.bucket is 'parallel' then split.splits[0] else split

class IdentityCombineToSplitValues
  constructor: ->
    null

  get: (filter, split, combine) ->
    return null unless @splitValues
    return null unless combine.method is 'slice'
    split = getRealSplit(split)
    combineSort = combine.sort
    return null unless combineSort
    sameSort = combineSort.isEqual(@sort)

    return null unless @complete or sameSort

    myFilter = filter.extractFilterByAttribute(split.attribute)?[1] or new TrueFilter()
    return null unless FacetFilter.filterSubset(myFilter, @filter)

    splitAttribute = split.attribute
    filterFn = myFilter.getFilterFn()
    filteredSplitValues = @splitValues.filter (splitValue) ->
      row = {}
      row[splitAttribute] = splitValue
      return filterFn(row)

    if sameSort and combine.limit? and combine.limit < filteredSplitValues.length
      filteredSplitValues = filteredSplitValues.slice(0, combine.limit)

    if @complete or (combine.limit? and combine.limit <= filteredSplitValues.length)
      return filteredSplitValues
    else
      return null

  # Check to see if I want it
  _want: (givenFilter, givenCombine, givenSplitValues) ->
    givenComplete = if givenCombine.limit? then givenSplitValues.length < givenCombine.limit else true

    # Take it if I have no values
    return true unless @splitValues

    # The filter should be at least as great or greater
    return false unless FacetFilter.filterSubset(@filter, givenFilter)

    # Do not accept non complete splits if I am complete
    return false if @complete and not givenComplete

    # All tests pass, return true
    return true

  set: (filter, split, combine, splitValues) ->
    return unless combine.method is 'slice'
    split = getRealSplit(split)
    myFilter = filter.extractFilterByAttribute(split.attribute)?[1] or new TrueFilter()
    completeInput = if combine.limit? then splitValues.length < combine.limit else true

    if @_want(myFilter, combine, splitValues)
      @filter = myFilter
      @sort = combine.sort
      @limit = combine.limit if combine.limit?
      @splitValues = splitValues
      @complete = if combine.limit? then splitValues.length < combine.limit else true

    return


class TimePeriodCombineToSplitValues
  constructor: ->

  get: (filter, split, combine) ->
    split = getRealSplit(split)
    duration = new Duration(split.period)
    timezone = split.timezone
    timeFilter = filter.extractFilterByAttribute(split.attribute)?[1]
    return null unless timeFilter?.type is 'within'
    [start, end] = timeFilter.range
    iter = duration.floor(start, timezone)
    splitValues = []
    next = duration.move(iter, timezone, 1)
    while next <= end
      splitValues.push([iter, next])
      iter = next
      next = duration.move(iter, timezone, 1)

    sort = combine.sort
    if sort.prop is split.name
      splitValues.reverse() if sort.direction is 'descending'
      driverUtil.inPlaceTrim(splitValues, combine.limit) if combine.limit?

    return splitValues

  set: ->
    return


class ContinuousCombineToSplitValues
  constructor: ->
    null

  get: (filter, split, combine) ->
    throw new Error('not implemented yet')

  set: ->
    return


module.exports = ({driver}) ->
  # Filter -> (Apply -> Number)
  applyCache = new LRUCache(filterToHash, 'apply')

  # (Filter, Split) -> CombineToSplitValues
  #              where CombineToSplitValues :: Combine -> [SplitValue]
  combineToSplitCache = new LRUCache(String, 'splitCombine')

  # ---------------------------------------------

  propFromCache = (filter, applyHashes) ->
    return {} unless applyHashes.length
    cacheCache = {}

    prop = {}
    for { name, hash, datasetFilter, datasetFilterHash } in applyHashes
      applyCacheSlot = cacheCache[datasetFilterHash]
      if not applyCacheSlot
        combinedFilter = new AndFilter([filter, datasetFilter])
        applyCacheSlot = cacheCache[datasetFilterHash] = applyCache.get(combinedFilter)
        return null unless applyCacheSlot

      value = applyCacheSlot[hash]
      return null unless value?
      prop[name] = value

    return prop


  getCondensedCommandFromCache = (datasetMap, filter, condensedCommands, idx) ->
    condensedCommand = condensedCommands[idx]
    idx++

    {
      appliesByDataset
      postProcessors
      #trackedSegregation: sortApplySegregation
    } = FacetApply.segregate(condensedCommand.applies) #, combine?.sort?.prop)

    applyHashes = appliesToHashes(appliesByDataset, datasetMap)

    split = condensedCommand.getEffectiveSplit()
    if split
      combine = condensedCommand.getCombine()
      filterSplitHash = filterSplitToHash(datasetMap, filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.getWithHash(filterSplitHash)
      return null unless combineToSplitsCacheSlot
      splitValues = combineToSplitsCacheSlot.get(filter, split, combine)
      return null unless splitValues
      segments = []
      for splitValue in splitValues
        splitValueProp = {}
        splitValueProp[split.name] = splitValue
        splitValueFilter = new AndFilter([filter, split.getFilterFor(splitValueProp)]).simplify()
        prop = propFromCache(splitValueFilter, applyHashes)
        return null unless prop
        postProcessor(prop) for postProcessor in postProcessors
        prop[split.name] = splitValue
        driverUtil.cleanProp(prop)
        segment = { prop }

        if idx < condensedCommands.length
          childSegments = getCondensedCommandFromCache(datasetMap, splitValueFilter, condensedCommands, idx)
          return null unless childSegments
          segment.splits = childSegments

        segments.push(segment)

      segments.sort(combine.sort.getSegmentCompareFn())
      driverUtil.inPlaceTrim(segments, combine.limit) if combine.limit?

      return segments

    else
      prop = propFromCache(filter, applyHashes)
      return null unless prop
      postProcessor(prop) for postProcessor in postProcessors
      driverUtil.cleanProp(prop)
      segment = { prop }

      if idx < condensedCommands.length
        childSegments = getCondensedCommandFromCache(datasetMap, filter, condensedCommands, idx)
        return null unless childSegments
        segment.splits = childSegments

      return [segment]


  # Try to extract the data for the query
  getQueryDataFromCache = (query) ->
    return getCondensedCommandFromCache(
      makeDatasetMap(query)
      query.getFilter()
      query.getCondensedCommands()
      0
    )?[0] or null

  # ------------------------

  propToCache = (prop, filter, applyHashes) ->
    return unless applyHashes.length
    cacheCache = {}
    for { name, hash, datasetFilter, datasetFilterHash } in applyHashes
      applyCacheSlot = cacheCache[datasetFilterHash]
      if not applyCacheSlot
        combinedFilter = new AndFilter([filter, datasetFilter])
        applyCacheSlot = cacheCache[datasetFilterHash] = applyCache.getOrCreate(combinedFilter, -> {})
      applyCacheSlot[hash] = prop[name]
    return

  saveCondensedCommandToCache = (segments, datasetMap, filter, condensedCommands, idx) ->
    condensedCommand = condensedCommands[idx]
    idx++

    {
      appliesByDataset
      #postProcessors
      #trackedSegregation: sortApplySegregation
    } = FacetApply.segregate(condensedCommand.applies) #, combine?.sort?.prop)

    applyHashes = appliesToHashes(appliesByDataset, datasetMap)

    split = condensedCommand.getEffectiveSplit()
    if split
      combine = condensedCommand.getCombine()

      filterSplitHash = filterSplitToHash(datasetMap, filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.getOrCreateWithHash(filterSplitHash, ->
        return switch getRealSplit(split).bucket
          when 'identity'   then new IdentityCombineToSplitValues(filter, split)
          when 'timePeriod' then new TimePeriodCombineToSplitValues(filter, split)
          when 'continuous' then new ContinuousCombineToSplitValues(filter, split)
      )

      splitValues = []
      for segment in segments
        splitValueFilter = new AndFilter([filter, split.getFilterFor(segment.prop)]).simplify()
        propToCache(segment.prop, splitValueFilter, applyHashes)
        splitValues.push(segment.prop[split.name])
        if idx < condensedCommands.length
          saveCondensedCommandToCache(segment.splits, datasetMap, splitValueFilter, condensedCommands, idx)

      combineToSplitsCacheSlot.set(filter, split, combine, splitValues)

    else
      segment = segments[0]
      return unless segment?.prop
      propToCache(segment.prop, filter, applyHashes)
      if idx < condensedCommands.length
        saveCondensedCommandToCache(segment.splits, datasetMap, filter, condensedCommands, idx)

    return

  saveQueryDataToCache = (data, query) ->
    saveCondensedCommandToCache(
      [data]
      makeDatasetMap(query)
      query.getFilter()
      query.getCondensedCommands()
      0
    )
    return

  # ------------------------

  cachedDriver = (request, callback) ->
    throw new Error("request not supplied") unless request
    {context, query} = request

    if query not instanceof FacetQuery
      callback(new Error("query must be a FacetQuery"))
      return

    useCache = query.getSplits().every((split) -> split.bucket isnt 'tuple') and
      query.getCombines().every((combine) -> (not combine?) or (combine instanceof SliceCombine))

    if useCache
      result = getQueryDataFromCache(query)
      if result
        callback(null, result)
        return

      driver request, (err, result) ->
        if err
          callback(err)
          return

        saveQueryDataToCache(result, query)
        callback(null, result)
        return
    else
      driver request, (err, result) ->
        if err
          callback(err)
          return

        callback(null, result)
        return

    return

  cachedDriver.clear = ->
    applyCache.clear()
    combineToSplitCache.clear()
    return

  cachedDriver.debug = ->
    console.log applyCache.store
    return

  return cachedDriver
