{ Duration } = require('chronology')
driverUtil = require('../driver/driverUtil')
SegmentTree = require('../driver/segmentTree')
{
  FacetQuery,
  AndFilter, TrueFilter, FacetFilter,
  FacetSplit,
  FacetApply,
  FacetCombine, SliceCombine
} = require('../query')


class LRUCache
  constructor: (@name = 'cache') ->
    @clear()

  clear: ->
    @store = {}
    @size = 0
    return

  get: (hash) ->
    return @store[hash] #?.value

  set: (hash, value) ->
    @size++ unless @store.hasOwnProperty(hash)
    @store[hash] = value
    # {
    #   value
    #   time: Date.now()
    # }
    return

  getOrCreate: (hash, createFn) ->
    ret = @get(hash)
    if not ret
      ret = createFn()
      @set(hash, ret)
    return ret

# -------------------------

filterToHash = (filter) ->
  return filter.simplify().toHash()


filterSplitToHash = (datasetMap, filter, split) ->
  splits = if split.bucket is 'parallel' then split.splits else [split]
  return splits.map((split) ->
    dataset = datasetMap[split.getDataset()]
    andFilter = new AndFilter([dataset.getFilter(), filter])
    extract = andFilter.extractFilterByAttribute(split.attribute)
    return dataset.source + '#' + filterToHash(extract[0]) + '//' + split.toHash()
  ).sort().join('*')


applyToHash = (apply, filter, datasetMap) ->
  dataset = datasetMap[apply.getDataset()]
  throw new Error("Something went wrong: could not find apply dataset") unless dataset
  datasetFilter = dataset.getFilter()
  return {
    name: apply.name
    apply
    applyHash: apply.toHash()
    segmentHash: dataset.source + '#' + filterToHash(new AndFilter([filter, datasetFilter]))
  }


appliesToHashes = (appliesByDataset, filter, datasetMap) ->
  applyHashes = []
  for datasetName, applies of appliesByDataset
    for apply in applies
      applyHashes.push(applyToHash(apply, filter, datasetMap))

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

  _getAllPossibleSplitValues: (filter, split) ->
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

    return splitValues

  get: (filter, split, combine) ->
    splitValues = @_getAllPossibleSplitValues(filter, split)
    return null unless splitValues

    if @knownUnknowns
      knownUnknowns = @knownUnknowns
      driverUtil.inPlaceFilter(splitValues, (splitValue) -> not knownUnknowns[splitValue[0].toISOString()])

    sort = combine.sort
    if sort.prop is split.name
      splitValues.reverse() if sort.direction is 'descending'
      driverUtil.inPlaceTrim(splitValues, combine.limit) if combine.limit?

    return splitValues

  set: (filter, split, combine, splitValues) ->
    return if combine.limit?
    possibleSplitValues = @_getAllPossibleSplitValues(filter, split)
    return unless possibleSplitValues
    return unless splitValues.length < possibleSplitValues.length
    hasSplitValue = {}
    for splitValue in splitValues
      return unless splitValue # ToDo: figure out null
      hasSplitValue[splitValue[0].toISOString()] = 1

    # The known unknown keys are the ISO interval starts of intervals we know for a fact are blank
    # We only need to store the start because they are all implicitly the same length.
    knownUnknowns = {}
    for possibleSplitValue in possibleSplitValues
      possibleSplitValueKey = possibleSplitValue[0].toISOString()
      if not hasSplitValue[possibleSplitValueKey]
        knownUnknowns[possibleSplitValueKey] = 1

    @knownUnknowns = knownUnknowns
    return


class ContinuousCombineToSplitValues
  constructor: ->

  get: (filter, split, combine) ->
    throw new Error('not implemented yet')

  set: ->
    return


module.exports = ({driver}) ->
  # Filter -> (Apply -> Number)
  applyCache = new LRUCache('apply')

  # (Filter, Split) -> CombineToSplitValues
  #              where CombineToSplitValues :: Combine -> [SplitValue]
  combineToSplitCache = new LRUCache('splitCombine')

  # ---------------------------------------------

  propFromCache = (applyHashes) ->
    prop = {}
    for { name, applyHash, segmentHash } in applyHashes
      applyCacheSlot = applyCache.get(segmentHash)
      return null unless applyCacheSlot

      value = applyCacheSlot[applyHash]
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

    split = condensedCommand.getEffectiveSplit()
    if split
      combine = condensedCommand.getCombine()
      filterSplitHash = filterSplitToHash(datasetMap, filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.get(filterSplitHash)
      return null unless combineToSplitsCacheSlot
      splitValues = combineToSplitsCacheSlot.get(filter, split, combine)
      return null unless splitValues
      segments = []
      for splitValue in splitValues
        splitValueProp = {}
        splitValueProp[split.name] = splitValue
        splitValueFilter = new AndFilter([filter, split.getFilterFor(splitValueProp)]).simplify()
        applyHashes = appliesToHashes(appliesByDataset, splitValueFilter, datasetMap)
        prop = propFromCache(applyHashes)
        return null unless prop
        postProcessor(prop) for postProcessor in postProcessors
        prop[split.name] = splitValue
        segment = new SegmentTree({prop})

        if idx < condensedCommands.length
          childSegments = getCondensedCommandFromCache(datasetMap, splitValueFilter, condensedCommands, idx)
          return null unless childSegments
          segment.setSplits(childSegments)

        segments.push(segment)

      segments.sort(combine.sort.getSegmentCompareFn())
      driverUtil.inPlaceTrim(segments, combine.limit) if combine.limit?

      return segments

    else
      applyHashes = appliesToHashes(appliesByDataset, filter, datasetMap)
      prop = propFromCache(applyHashes)
      return null unless prop
      postProcessor(prop) for postProcessor in postProcessors
      segment = new SegmentTree({prop})

      if idx < condensedCommands.length
        childSegments = getCondensedCommandFromCache(datasetMap, filter, condensedCommands, idx)
        return null unless childSegments
        segment.setSplits(childSegments)

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

  propToCache = (prop, applyHashes) ->
    return unless applyHashes.length
    for { name, applyHash, segmentHash } in applyHashes
      applyCacheSlot = applyCache.getOrCreate(segmentHash, -> {})
      applyCacheSlot[applyHash] = prop[name]
    return

  saveCondensedCommandToCache = (segments, datasetMap, filter, condensedCommands, idx) ->
    return unless segments
    condensedCommand = condensedCommands[idx]
    idx++

    {
      appliesByDataset
      #postProcessors
      #trackedSegregation: sortApplySegregation
    } = FacetApply.segregate(condensedCommand.applies)

    split = condensedCommand.getEffectiveSplit()
    if split
      combine = condensedCommand.getCombine()

      filterSplitHash = filterSplitToHash(datasetMap, filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.getOrCreate(filterSplitHash, ->
        return switch getRealSplit(split).bucket
          when 'identity'   then new IdentityCombineToSplitValues(filter, split)
          when 'timePeriod' then new TimePeriodCombineToSplitValues(filter, split)
          when 'continuous' then new ContinuousCombineToSplitValues(filter, split)
      )

      splitValues = []
      for segment in segments
        splitValueFilter = new AndFilter([filter, split.getFilterFor(segment.prop)]).simplify()
        applyHashes = appliesToHashes(appliesByDataset, splitValueFilter, datasetMap)
        propToCache(segment.prop, applyHashes)
        splitValues.push(segment.prop[split.name])
        if idx < condensedCommands.length
          saveCondensedCommandToCache(segment.splits, datasetMap, splitValueFilter, condensedCommands, idx)

      combineToSplitsCacheSlot.set(filter, split, combine, splitValues)

    else
      segment = segments[0]
      return unless segment?.prop
      applyHashes = appliesToHashes(appliesByDataset, filter, datasetMap)
      propToCache(segment.prop, applyHashes)
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

    useCache = query.getSplits().every((split) -> split.bucket isnt 'tuple' and not split.segmentFilter) and
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
      driver(request, callback)

    return

  cachedDriver.clear = ->
    applyCache.clear()
    combineToSplitCache.clear()
    return

  cachedDriver.debug = ->
    console.log applyCache.store
    return

  return cachedDriver
