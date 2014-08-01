"use strict"

{ Duration } = require('chronology')

{isInstanceOf} = require('../util')
driverUtil = require('../driver/driverUtil')
SegmentTree = require('../driver/segmentTree')
{
  FacetQuery,
  FacetDataset,
  AndFilter, OrFilter, TrueFilter, FacetFilter,
  FacetSplit,
  FacetApply,
  FacetCombine, SliceCombine
  ApplySimplifier
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

applySimplifierSettings = {
  namePrefix: 'c_S'
  breakToSimple: true
  topLevelConstant: 'process'
}

# -------------------------

filterToHash = (filter) ->
  return filter.simplify().toHash()


filterSplitToHash = (datasetMap, filter, split) ->
  splits = if split.bucket is 'parallel' then split.splits else [split]
  return splits.map((split) ->
    dataset = datasetMap[split.getDataset()]
    andFilter = new AndFilter([dataset.getFilter(), filter])
    if extract = andFilter.extractFilterByAttribute(split.attribute)
      return "#{dataset.source}##{filterToHash(extract[0])}//#{split.toHash()}"
    else
      return "#{dataset.source}#BAD//#{split.toHash()}"
  ).sort().join('*')


applyToHash = (apply, filter, datasetMap) ->
  dataset = datasetMap[apply.getDataset()]
  if not dataset
    throw new Error("Something went wrong: could not find apply dataset")
  datasetFilter = dataset.getFilter()
  return {
    name: apply.name
    apply
    applyHash: apply.toHash()
    segmentHash: dataset.source + '#' + filterToHash(new AndFilter([filter, datasetFilter]))
  }


appliesToHashes = (simpleApplies, filter, datasetMap) ->
  return simpleApplies.map((apply) -> applyToHash(apply, filter, datasetMap))


makeDatasetMap = (query) ->
  datasets = query.getDatasets()
  map = {}
  map[dataset.name] = dataset for dataset in datasets
  return map


betterThanExistingSlot = (sortSlot, givenFilter, givenCombine, givenSplitValues) ->
  return true unless sortSlot
  givenComplete = if givenCombine.limit? then givenSplitValues.length < givenCombine.limit else true

  # Take it if sortSlot has no values
  return true unless sortSlot.splitValues

  # The filter should be at least as great or greater
  return false unless FacetFilter.filterSubset(sortSlot.filter, givenFilter)

  # Do not accept non complete splits if I am complete
  return false if sortSlot.complete and not givenComplete

  # All tests pass, return true
  return true


canServeFromSlot = (sortSlot, givenFilter, givenCombine) ->
  return false unless sortSlot and FacetFilter.filterSubset(givenFilter, sortSlot.filter)

  return true if sortSlot.complete

  return false unless givenCombine.limit

  return givenCombine.limit <= sortSlot.limit


getFilteredValuesFromSlot = (sortSlot, split, myFilter) ->
  return sortSlot.splitValues.slice() if myFilter.type is 'true'
  splitAttribute = split.attribute
  filterFn = myFilter.getFilterFn()
  return sortSlot.splitValues.filter (splitValue) ->
    row = {}
    row[splitAttribute] = splitValue
    return filterFn(row)


isCompleteInput = (givenFilter, givenCombine, givenSplitValues) ->
  return false unless givenFilter.type is 'true'
  return if givenCombine.limit? then givenSplitValues.length < givenCombine.limit else true


getRealSplit = (split) ->
  return if split.bucket is 'parallel' then split.splits[0] else split

class IdentityCombineToSplitValues
  constructor: ->
    @bySort = {}

  set: (filter, condensedCommand, splitValues) ->
    split = getRealSplit(condensedCommand.split)
    combine = condensedCommand.combine
    return unless filterExtract = filter.extractFilterByAttribute(split.attribute)
    myFilter = filterExtract[1]

    sortHash = condensedCommand.getSortHash()
    sortSlot = @bySort[sortHash]

    if betterThanExistingSlot(sortSlot, myFilter, combine, splitValues)
      sortSlot = {
        filter: myFilter
        splitValues
      }

      if isCompleteInput(myFilter, combine, splitValues)
        sortSlot.complete = true
      else
        sortSlot.limit = combine.limit

      @bySort[sortHash] = sortSlot

    return

  _findComplete: ->
    for k, slot of @bySort
      return slot if slot.complete
    return null

  get: (filter, condensedCommand, flags) ->
    split = getRealSplit(condensedCommand.split)
    combine = condensedCommand.combine

    if not filterExtract = filter.extractFilterByAttribute(split.attribute)
      flags.fullQuery = true
      return null

    myFilter = filterExtract[1]

    sortHash = condensedCommand.getSortHash()
    sortSlot = @bySort[sortHash]
    if canServeFromSlot(sortSlot, filter, combine)
      filteredSplitValues = getFilteredValuesFromSlot(sortSlot, split, myFilter)

      if combine.limit? and combine.limit <= filteredSplitValues.length
        driverUtil.inPlaceTrim(filteredSplitValues, combine.limit)
        return filteredSplitValues
      else # sortSlot.complete
        flags.fullQuery = true # why?
        return filteredSplitValues
    else
      completeSlot = @_findComplete()
      return null unless completeSlot
      return getFilteredValuesFromSlot(completeSlot, split, myFilter)


class TimePeriodCombineToSplitValues
  constructor: ->
    @bySort = {}

  _getAllPossibleSplitValues: (myFilter, split) ->
    [start, end] = myFilter.range # Assume WithinFilter
    duration = new Duration(split.period)
    timezone = split.timezone
    iter = duration.floor(start, timezone)
    splitValues = []
    next = duration.move(iter, timezone, 1)
    while next <= end
      splitValues.push([iter, next])
      iter = next
      next = duration.move(iter, timezone, 1)

    return splitValues

  _calculateKnownUnknowns: (possibleSplitValues, splitValues) ->
    hasSplitValue = {}
    for splitValue in splitValues
      continue unless splitValue # ToDo: figure out null
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

  _getPossibleKnownSplitValues: (myFilter, split) ->
    splitValues = @_getAllPossibleSplitValues(myFilter, split)

    if @knownUnknowns
      knownUnknowns = @knownUnknowns
      driverUtil.inPlaceFilter(splitValues, (splitValue) -> not knownUnknowns[splitValue[0].toISOString()])

    return splitValues

  _makeRange: (split, splitValues) ->
    duration = new Duration(split.period)
    timezone = split.timezone
    return splitValues.map((splitValue) -> [splitValue, duration.move(splitValue, timezone, 1)])

  set: (filter, condensedCommand, splitValues) ->
    split = getRealSplit(condensedCommand.split)
    combine = condensedCommand.combine
    return unless filterExtract = filter.extractFilterByAttribute(split.attribute)
    myFilter = filterExtract[1]
    return unless myFilter.type is 'within'

    sort = combine.sort
    if sort.prop is split.name
      return if combine.limit?
      possibleSplitValues = @_getAllPossibleSplitValues(myFilter, split)
      return unless splitValues.length < possibleSplitValues.length
      @_calculateKnownUnknowns(possibleSplitValues, splitValues)
    else
      sortHash = condensedCommand.getSortHash()
      sortSlot = @bySort[sortHash]

      if betterThanExistingSlot(sortSlot, myFilter, combine, splitValues)
        sortSlot = {
          filter: myFilter
          splitValues: splitValues.map(([start]) -> start)
        }

        if isCompleteInput(myFilter, combine, splitValues)
          sortSlot.complete = true
        else
          sortSlot.limit = combine.limit

        @bySort[sortHash] = sortSlot

    return

  get: (filter, condensedCommand, flags) ->
    split = getRealSplit(condensedCommand.split)
    combine = condensedCommand.combine

    if not filterExtract = filter.extractFilterByAttribute(split.attribute)
      flags.fullQuery = true
      return null

    myFilter = filterExtract[1]
    if myFilter.type isnt 'within'
      flags.fullQuery = true
      return null

    sort = combine.sort
    if sort.prop is split.name
      splitValues = @_getPossibleKnownSplitValues(myFilter, split)
      splitValues.reverse() if sort.direction is 'descending'
      driverUtil.inPlaceTrim(splitValues, combine.limit) if combine.limit?
      return splitValues
    else
      sortHash = condensedCommand.getSortHash()
      sortSlot = @bySort[sortHash]
      if canServeFromSlot(sortSlot, filter, combine)
        filteredSplitValues = getFilteredValuesFromSlot(sortSlot, split, myFilter)

        if combine.limit? and combine.limit <= filteredSplitValues.length
          driverUtil.inPlaceTrim(filteredSplitValues, combine.limit)
        else # sortSlot.complete
          flags.fullQuery = true

        return @_makeRange(split, filteredSplitValues)
      else
        return @_getPossibleKnownSplitValues(myFilter, split)


class ContinuousCombineToSplitValues
  constructor: ->

  get: (filter, condensedCommand, flags) ->
    throw new Error('not implemented yet')

  set: (filter, condensedCommand, splitValues) ->
    return

# ------------------------

sortedApplyValues = (hashToApply) ->
  return if hashToApply then Object.keys(hashToApply).sort().map((h) -> hashToApply[h]) else []

addSortByIfNeeded = (applies, sortBy) ->
  if isInstanceOf(sortBy, FacetApply) and not driverUtil.find(applies, ({name}) -> name is sortBy.name)
    applies.push(sortBy)
  return

nextLayer = (segments) ->
  return driverUtil.flatten(driverUtil.filterMap(segments, ({splits}) -> splits))

nextLoadingLayer = (segments) ->
  return nextLayer(segments).filter((segment) -> segment.hasLoading())

gatherMissingApplies = (segments) ->
  totalMissingApplies = null
  for segment in segments
    segmentMissingApplis = segment.$_missingApplies
    continue unless segmentMissingApplis
    totalMissingApplies or= {}
    totalMissingApplies[k] = v for k, v of segmentMissingApplis
  return totalMissingApplies

computeDeltaQuery = (originalQuery, rootSegment) ->
  datasets = originalQuery.getDatasets()
  andFilters = [originalQuery.getFilter()]
  condensedCommands = originalQuery.getCondensedCommands()
  newQuery = if datasets.length is 1 and datasets[0].name is 'main' then [] else datasets.slice()

  i = 0
  prevLayer = [{ splits: [rootSegment] }] # Pre-root
  currentLayer = nextLoadingLayer(prevLayer)

  # Walk filters
  while (not prevLayer[0].loading) and currentLayer.length is 1
    if split = condensedCommands[i].split
      andFilters.push(split.getFilterFor(currentLayer[0].prop))

    prevLayer = currentLayer
    currentLayer = nextLoadingLayer(prevLayer)
    i++

  # Add pre-applies if needed
  if not prevLayer[0].$_missingApplies and currentLayer.length and split = condensedCommands[i].split
    segmentsFilter = new OrFilter(currentLayer.map((segment) -> split.getFilterFor(segment.prop))).simplify()
    andFilters.push(segmentsFilter) if segmentsFilter.type isnt 'or' # Only add if it can be simplified to something basic

  newFilter = new AndFilter(andFilters).simplify()
  newQuery.push(newFilter) unless newFilter.type is 'true'

  if prevLayer[0].$_missingApplies
    sortedMissingApplies = sortedApplyValues(gatherMissingApplies(prevLayer))
    newQuery = newQuery.concat(sortedMissingApplies)

  # Figure out next layers
  noSegmentFilter = i > 1 # Hack?
  while condensedCommand = condensedCommands[i]
    # If there are segments in the current layer and we are not missing
    # any applies wholesale because of split-less segments in the prev layer
    if currentLayer.length and prevLayer.every((segment) -> segment.splits)
      if noSegmentFilter
        newQuery.push(condensedCommand.split.withoutSegmentFilter())
      else
        newQuery.push(condensedCommand.split)
      sortedMissingApplies = sortedApplyValues(gatherMissingApplies(currentLayer))
      addSortByIfNeeded(sortedMissingApplies, condensedCommand.getSortBy())
      newQuery = newQuery.concat(sortedMissingApplies)
      newQuery.push(condensedCommand.combine)
    else
      if noSegmentFilter
        newQuery.push(condensedCommand.split.withoutSegmentFilter())
      else
        newQuery.push(condensedCommand.split)

      applySimplifier = new ApplySimplifier(applySimplifierSettings)
      applySimplifier.addApplies(condensedCommand.applies)
      simpleApplies = applySimplifier.getSimpleApplies()
      addSortByIfNeeded(simpleApplies, condensedCommand.getSortBy())
      newQuery = newQuery.concat(simpleApplies)
      newQuery.push(condensedCommand.combine)

    prevLayer = currentLayer
    currentLayer = nextLoadingLayer(prevLayer)
    i++

  return new FacetQuery(newQuery)

# ------------------------

module.exports = ({driver}) ->
  # Filter -> (Apply -> Number)
  applyCache = new LRUCache('apply')

  # (Filter, Split) -> CombineToSplitValues
  #              where CombineToSplitValues :: Combine -> [SplitValue]
  combineToSplitCache = new LRUCache('splitCombine')

  # ---------------------------------------------
  cleanCacheProp = (prop) ->
    for key, value of prop
      if key.substring(0, 3) is 'c_S'
        delete prop[key]
    return

  fillPropFromCache = (prop, applyHashes) ->
    missingApplies = null
    for { name, apply, applyHash, segmentHash } in applyHashes
      applyCacheSlot = applyCache.get(segmentHash)
      if not applyCacheSlot or not (value = applyCacheSlot[applyHash])?
        missingApplies or= {}
        missingApplies[applyHash] = apply
        continue

      prop[name] = value
    return missingApplies

  constructSegmentProp = (segment, datasetMap, simpleApplies, postProcessors) ->
    applyHashes = appliesToHashes(simpleApplies, segment.$_filter, datasetMap)
    segmentProp = segment.prop
    missingApplies = fillPropFromCache(segmentProp, applyHashes)
    if missingApplies
      cleanCacheProp(segmentProp)
      segment.markLoading()
      segment.$_missingApplies = missingApplies
    else
      postProcessor(segmentProp) for postProcessor in postProcessors
      cleanCacheProp(segmentProp)
    return


  # Try to extract the data for the query
  getQueryDataFromCache = (query) ->
    datasetMap = makeDatasetMap(query)
    rootSegment = new SegmentTree({ prop: {} })
    rootSegment.$_filter = query.getFilter()
    condensedCommands = query.getCondensedCommands()
    currentLayerGroups = [[rootSegment]]

    for condensedCommand, i in condensedCommands
      # Simplify
      applySimplifier = new ApplySimplifier(applySimplifierSettings)
      applySimplifier.addApplies(condensedCommand.applies)
      simpleApplies = applySimplifier.getSimpleApplies()
      postProcessors = applySimplifier.getPostProcessors()

      # Retrieve all the applies for the current layer
      for layerGroup in currentLayerGroups
        for segment in layerGroup
          constructSegmentProp(segment, datasetMap, simpleApplies, postProcessors)

      # Do combine if needed
      if combine = condensedCommand.getCombine()
        compareFn = combine.sort.getSegmentCompareFn()
        for layerGroup in currentLayerGroups
          layerGroup.sort(compareFn)
          driverUtil.inPlaceTrim(layerGroup, combine.limit) if combine.limit?
          layerGroup.$_parent.setSplits(layerGroup)

      # Compute next split
      if nextCondensedCommand = condensedCommands[i + 1]
        split = nextCondensedCommand.getEffectiveSplit()
        splitName = split.name
        segmentFilterFn = if split.segmentFilter then split.segmentFilter.getFilterFn() else null

        #combine = nextCondensedCommand.getCombine()

        flatLayer = driverUtil.flatten(currentLayerGroups)
        flatLayer = flatLayer.filter(segmentFilterFn) if segmentFilterFn
        break if flatLayer.length is 0 # shortcut

        currentLayerGroups = []
        for segment in flatLayer
          filterSplitHash = filterSplitToHash(datasetMap, segment.$_filter, split)
          combineToSplitsCacheSlot = combineToSplitCache.get(filterSplitHash)
          flags = {}
          if not combineToSplitsCacheSlot or not splitValues = combineToSplitsCacheSlot.get(segment.$_filter, nextCondensedCommand, flags)
            rootSegment.$_fullQuery = true if flags.fullQuery
            segment.markLoading()
            continue

          rootSegment.$_fullQuery = true if flags.fullQuery

          layerGroup = splitValues.map (splitValue) ->
            initProp = {}
            initProp[splitName] = splitValue
            childSegment = new SegmentTree({ prop: initProp }, segment)
            childSegment.$_filter = new AndFilter([segment.$_filter, split.getFilterFor(initProp)]).simplify()
            return childSegment

          layerGroup.$_parent = segment
          currentLayerGroups.push(layerGroup)

    return rootSegment

  # ------------------------

  propToCache = (prop, applyHashes) ->
    return unless applyHashes.length
    for { name, applyHash, segmentHash } in applyHashes
      applyCacheSlot = applyCache.getOrCreate(segmentHash, -> {})
      applyCacheSlot[applyHash] = prop[name]
    return

  saveSegmentProp = (segment, datasetMap, simpleApplies) ->
    return unless segment.prop
    applyHashes = appliesToHashes(simpleApplies, segment.$_filter, datasetMap)
    propToCache(segment.prop, applyHashes)
    return

  saveQueryDataToCache = (rootSegment, query) ->
    datasetMap = makeDatasetMap(query)
    condensedCommands = query.getCondensedCommands()
    rootSegment.$_filter = query.getFilter()
    currentLayer = [rootSegment]

    for condensedCommand, i in condensedCommands
      # Simplify
      applySimplifier = new ApplySimplifier(applySimplifierSettings)
      applySimplifier.addApplies(condensedCommand.applies)
      simpleApplies = applySimplifier.getSimpleApplies()

      # Save all applies in current layer
      for segment in currentLayer
        saveSegmentProp(segment, datasetMap, simpleApplies)

      # Save split
      if nextCondensedCommand = condensedCommands[i + 1]
        split = nextCondensedCommand.getEffectiveSplit()
        splitName = split.name
        CacheSlotConstructor = switch getRealSplit(split).bucket
          when 'identity'   then IdentityCombineToSplitValues
          when 'timePeriod' then TimePeriodCombineToSplitValues
          when 'continuous' then ContinuousCombineToSplitValues

        #combine = nextCondensedCommand.getCombine()

        currentLayer = driverUtil.flatten(driverUtil.filterMap(currentLayer, (segment) ->
          return unless segment.splits
          filter = segment.$_filter
          filterSplitHash = filterSplitToHash(datasetMap, filter, split)
          combineToSplitsCacheSlot = combineToSplitCache.getOrCreate(filterSplitHash, -> new CacheSlotConstructor(filter, split))

          splitValues = []
          for childSegment in segment.splits
            childSegment.$_filter = new AndFilter([filter, split.getFilterFor(childSegment.prop)]).simplify()
            splitValues.push(childSegment.prop[splitName])

          combineToSplitsCacheSlot.set(filter, nextCondensedCommand, splitValues)
          return segment.splits
        ))

    return

  # ------------------------

  cachedDriver = (request, callback, intermediate) ->
    throw new Error("request not supplied") unless request
    {context, query} = request

    if not isInstanceOf(query, FacetQuery)
      callback(new Error("query must be a FacetQuery"))
      return

    useCache = (not context?.dontCache) and
      query.getSplits().every((split) -> split.bucket isnt 'tuple') and
      query.getCombines().every((combine) -> (not combine?) or isInstanceOf(combine, SliceCombine))

    if useCache
      flags = {}
      rootSegment = getQueryDataFromCache(query)
      if rootSegment.hasLoading()
        intermediate?(rootSegment)
      else
        callback(null, rootSegment)
        return

      if rootSegment.$_fullQuery
        # The cache gave up on constructing an incremental query,
        # let's just query the whole thing and save the results.
        driver({
          query
          context
        }, (err, fullResult) ->
          if err
            callback(err)
            return

          saveQueryDataToCache(fullResult, query)
          callback(null, fullResult)
          return
        )
      else
        # The cache gave us an incremental query, let's query it,
        # then fill the cache with this info and then ask the cache
        # to fill the original query again.
        deltaQuery = computeDeltaQuery(query, rootSegment)

        driver({
          query: deltaQuery
          context
        }, (err, deltaResult) ->
          if err
            callback(err)
            return

          saveQueryDataToCache(deltaResult, deltaQuery)

          rootSegment = getQueryDataFromCache(query)
          if rootSegment.hasLoading()
            console.log 'stillLoading', rootSegment.valueOf()
            cachedDriver.debug()
            callback(new Error('total cache error'))
          else
            callback(null, rootSegment)
          return
        )
    else
      driver(request, callback)

    return

  cachedDriver.clear = ->
    applyCache.clear()
    combineToSplitCache.clear()
    return

  cachedDriver.debug = ->
    console.log 'applyCache'
    console.log "Size: #{applyCache.size}"
    for k, v of applyCache.store
      console.log k, JSON.stringify(v)

    console.log 'combineToSplitCache'
    console.log "Size: #{combineToSplitCache.size}"
    for k, v of combineToSplitCache.store
      console.log k, JSON.stringify(v)
    return

  return cachedDriver


module.exports.computeDeltaQuery = computeDeltaQuery

module.exports.cacheSlots = {
  IdentityCombineToSplitValues
  TimePeriodCombineToSplitValues
  ContinuousCombineToSplitValues
}
