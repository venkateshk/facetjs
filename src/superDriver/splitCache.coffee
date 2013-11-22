`(typeof window === 'undefined' ? {} : window)['splitCache'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
driverUtil = require('./driverUtil')
{ Duration } = require('./chronology')
{ FacetQuery, AndFilter, TrueFilter, FacetFilter, FacetSplit, FacetCombine } = require('./query')


class LRUCache
  constructor: (@hashFn = String, @name = 'cache') ->
    @store = {}
    @size = 0

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
      when 'and'      then "A(#{filter.filters.map(filterToHashHelper).join(')(')})"
      when 'or'       then "O(#{filter.filters.map(filterToHashHelper).join(')(')})"
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


filterSplitToHash = (filter, split) ->
  extract = filter.extractFilterByAttribute(split.attribute)
  return (if extract then filterToHash(extract[0]) else filterToHash(filter)) + '//' + splitToHash(split)


appliesToHashes = (applies) ->
  return applies.map (apply) ->
    return {
      name: apply.name
      hash: applyToHash(apply)
    }


class IdentityCombineToSplitValues
  constructor: ->
    null

  get: (filter, split, combine) ->
    return null unless @splitValues
    return null unless combine.method is 'slice'
    myFilter = filter.extractFilterByAttribute(split.attribute)?[1]

    if myFilter
      if @complete
        splitAttribute = split.attribute
        filterFn = myFilter.getFilterFn()
        return @splitValues.filter (splitValue) ->
          row = {}
          row[splitAttribute] = splitValue
          return filterFn(row)
      else
        return null unless myFilter.type in ['is', 'in']
        values = if myFilter.type is 'is' then [myFilter.value] else myFilter.values
        for value in values
          return null unless value in @splitValues
        return values

    else
      combineSort = combine.sort
      return null unless combineSort

      if combine.limit? and combineSort.isEqual(@sort) and combine.limit <= @limit
        return @splitValues.slice(0, combine.limit)

      return if @complete then @splitValues else null

  set: (filter, split, combine, splitValues) ->
    return unless combine.method is 'slice'
    @sort = combine.sort
    @splitValues = splitValues
    if combine.limit?
      @limit = combine.limit
      @complete = @splitValues.length < @limit
    else
      @complete = true

    return


class TimePeriodCombineToSplitValues
  constructor: ->

  get: (filter, split, combine) ->
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

  get: (combine) ->
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
    applyCacheSlot = applyCache.get(filter)
    return null unless applyCacheSlot

    prop = {}
    for { name, hash } in applyHashes
      value = applyCacheSlot[hash]
      return null unless value?
      prop[name] = value

    return prop


  getCondensedCommandFromCache = (filter, condensedCommands, idx) ->
    condensedCommand = condensedCommands[idx]
    return false unless condensedCommand
    applyHashes = appliesToHashes(condensedCommand.applies)

    split = condensedCommand.split
    if split
      combine = condensedCommand.combine
      return null unless combine
      filterSplitHash = filterSplitToHash(filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.getWithHash(filterSplitHash)
      return null unless combineToSplitsCacheSlot
      splitValues = combineToSplitsCacheSlot.get(filter, split, combine)
      return null unless splitValues
      segments = []
      for splitValue in splitValues
        splitValueProp = {}
        splitValueProp[split.name] = splitValue
        segmentFilter = new AndFilter([filter, split.getFilterFor(splitValueProp)]).simplify()
        prop = propFromCache(segmentFilter, applyHashes)
        return null unless prop
        prop[split.name] = splitValue
        childSegments = getCondensedCommandFromCache(segmentFilter, condensedCommands, idx + 1)
        return null unless childSegments?
        segment = { prop }
        segment.splits = childSegments if childSegments
        segments.push(segment)

      segments.sort(combine.sort.getSegmentCompareFn())
      driverUtil.inPlaceTrim(segments, combine.limit) if combine.limit?

      return segments

    else
      prop = propFromCache(filter, applyHashes)
      return null unless prop
      childSegments = getCondensedCommandFromCache(filter, condensedCommands, idx + 1)
      return null unless childSegments?
      segment = { prop }
      segment.splits = childSegments if childSegments
      return [segment]


  # Try to extract the data for the query
  getQueryDataFromCache = (query) ->
    return getCondensedCommandFromCache(query.getFilter(), query.getGroups(), 0)?[0] or null

  # ------------------------

  propToCache = (prop, filter, applyHashes) ->
    return unless applyHashes.length
    applyCacheSlot = applyCache.getOrCreate(filter, -> {})
    for { name, hash } in applyHashes
      applyCacheSlot[hash] = prop[name]
    return

  saveCondensedCommandToCache = (segments, filter, condensedCommands, idx) ->
    condensedCommand = condensedCommands[idx]
    return unless condensedCommand
    applyHashes = appliesToHashes(condensedCommand.applies)

    split = condensedCommand.split
    if split
      combine = condensedCommand.combine
      return unless combine

      filterSplitHash = filterSplitToHash(filter, split)
      combineToSplitsCacheSlot = combineToSplitCache.getOrCreateWithHash(filterSplitHash, ->
        return switch split.bucket
          when 'identity'   then new IdentityCombineToSplitValues(filter, split)
          when 'timePeriod' then new TimePeriodCombineToSplitValues(filter, split)
          when 'continuous' then new ContinuousCombineToSplitValues(filter, split)
      )

      splitValues = []
      for segment in segments
        segmentFilter = new AndFilter([filter, split.getFilterFor(segment.prop)]).simplify()
        propToCache(segment.prop, segmentFilter, applyHashes)
        splitValues.push(segment.prop[split.name])
        saveCondensedCommandToCache(segment.splits, segmentFilter, condensedCommands, idx + 1)

      combineToSplitsCacheSlot.set(filter, split, combine, splitValues)

    else
      segment = segments[0]
      return unless segment?.prop
      propToCache(segment.prop, filter, applyHashes)
      saveCondensedCommandToCache(segment.splits, filter, condensedCommands, idx + 1)

    return

  saveQueryDataToCache = (data, query) ->
    saveCondensedCommandToCache([data], query.getFilter(), query.getGroups(), 0)
    return

  # ------------------------

  return (request, callback) ->
    throw new Error("request not supplied") unless request
    {context, query} = request

    if query not instanceof FacetQuery
      callback(new Error("query must be a FacetQuery"))
      return

    # Skip if:
    # - tuple split
    # - non slice combine (or no combine)

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
