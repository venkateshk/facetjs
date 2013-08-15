`(typeof window === 'undefined' ? {} : window)['driverUtil'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
timezoneJS = require('timezone-js') or require('./timezoneJS')
tz_info = require('../utils/timezone') or require('mmx_tz_info')

tz = timezoneJS.timezone
tz.loadingScheme = tz.loadingSchemes.MANUAL_LOAD
tz.loadZoneDataFromObject(tz_info)

# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (ar) -> Array::concat.apply([], ar)

# Trims the array in place
exports.inPlaceTrim = (array, n) ->
  return if array.length < n
  array.splice(n, array.length - n)
  return


# Filter the array in place
exports.inPlaceFilter = (array, fn) ->
  i = 0
  while i < array.length
    if fn.call(array, array[i], i)
      i++
    else
      array.splice(i, 1)
  return


# Filter and map (how is this method not part of native JS?!)
exports.filterMap = (array, fn) ->
  ret = []
  for a in array
    v = fn(a)
    continue if typeof v is 'undefined'
    ret.push(v)
  return ret


# Construct a filter that represents the split
exports.filterFromSplit = filterFromSplit = (split, propValue) ->
  switch split.bucket
    when 'identity'
      return {
        type: 'is'
        attribute: split.attribute
        value: propValue
      }
    when 'continuous', 'timeDuration', 'timePeriod'
      return {
        type: 'within'
        attribute: split.attribute
        range: propValue
      }
    when 'tuple'
      throw new Error("tuple split not supported yet")
    else
      throw new Error("missing bucket") unless split.bucket
      throw new Error("unknown bucketing: #{split.bucket}")


# Check if the apply is additive
exports.isAdditiveApply = isAdditiveApply = (apply) ->
  return apply.aggregate in ['constant', 'count', 'sum'] or
         (apply.arithmetic in ['add', 'subtract'] and
           isAdditiveApply(apply.operands[0]) and
           isAdditiveApply(apply.operands[1]))

getPropFromSegment = (segment, prop) ->
  return null unless segment and segment.prop
  return segment.prop[prop] or getPropFromSegment(segment.parent, prop)

bucketFilterFns = {
  false: ->
    return -> false

  is: ({prop, value}) ->
    if Array.isArray(value)
      # value can also be a range for direct interval comparisons
      [start, end] = value
      start = Date.parse(start) if typeof start is 'string'
      end = Date.parse(end) if typeof end is 'string'
      return (segment) ->
        [segStart, segEnd] = getPropFromSegment(segment, prop)
        return segStart.valueOf() is start and segEnd.valueOf() is end
    else
      return (segment) -> getPropFromSegment(segment, prop) is value

  in: ({prop, values}) ->
    return (segment) -> getPropFromSegment(segment, prop) in values

  within: ({prop, range}) ->
    throw new TypeError("range must be an array of two things") unless Array.isArray(range) and range.length is 2
    return (segment) -> range[0] <= getPropFromSegment(segment, prop) < range[1]

  not: ({filter}) ->
    throw new TypeError("filter must be a filter object") unless typeof filter is 'object'
    filter = makeBucketFilterFn(filter)
    return (segment) -> not filter(segment)

  and: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeBucketFilterFn)
    return (segment) ->
      for filter in filters
        return false unless filter(segment)
      return true

  or: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeBucketFilterFn)
    return (segment) ->
      for filter in filters
        return true if filter(segment)
      return false
}

exports.makeBucketFilterFn = makeBucketFilterFn = (filter) ->
  throw new Error("type not defined in filter") unless filter.hasOwnProperty('type')
  throw new Error("invalid type in filter") unless typeof filter.type is 'string'
  bucketFilterFn = bucketFilterFns[filter.type]
  throw new Error("bucket filter type '#{filter.type}' not defined") unless bucketFilterFn
  return bucketFilterFn(filter)


# Group the queries steps in to the logical queries that will need to be done
# output: [
#   {
#     filter: { ... }
#     split: { ... }
#     applies: [{ ... }, { ... }]
#     combine: { ... }
#   }
#   ...
# ]
exports.condenseQuery = (query) ->
  throw new Error("query not supplied") unless query
  throw new Error("invalid query") unless Array.isArray(query)
  curQuery = {
    filter: null
    split: null
    applies: []
    combine: null
  }
  curKnownProps = {}
  condensed = []
  for cmd in query
    switch cmd.operation
      when 'filter'
        throw new Error("can not have more than one filter") if curQuery.filter
        throw new Error("type not defined in filter") unless cmd.hasOwnProperty('type')
        throw new Error("invalid type in filter") unless typeof cmd.type is 'string'
        curQuery.filter = upgradeFilter(cmd)

      when 'split'
        condensed.push(curQuery)
        if cmd.bucket is 'tuple'
          throw new Error("tuple split must have splits") unless cmd.splits
        else
          throw new Error("name not defined in split") unless cmd.name
          throw new TypeError("invalid name in split") unless typeof cmd.name is 'string'
          throw new Error("split must have an attribute") unless cmd.attribute
          throw new TypeError("invalid attribute in split") unless typeof cmd.attribute is 'string'

        curQuery = {
          split: cmd
          applies: []
          combine: null
        }
        curKnownProps = {}
        curKnownProps[cmd.name] = true

      when 'apply'
        throw new Error("name not defined in apply") unless cmd.name
        throw new TypeError("invalid name in apply") unless typeof cmd.name is 'string'
        curQuery.applies.push(cmd)
        curKnownProps[cmd.name] = true

      when 'combine'
        throw new Error("combine called without split") unless curQuery.split
        throw new Error("can not have more than one combine") if curQuery.combine
        throw new Error("combine not defined in combine") unless cmd.hasOwnProperty('combine')

        if cmd.sort
          throw new Error("sort must have a prop") unless cmd.sort.prop
          throw new Error("sort on undefined prop '#{cmd.sort.prop}'") unless curKnownProps[cmd.sort.prop]
          throw new Error("sort must have a compare") unless cmd.sort.compare
          throw new Error("sort must have a direction") unless cmd.sort.direction

          if cmd.sort.direction not in ['ascending', 'descending']
            throw new Error("sort direction has to be 'ascending' or 'descending'")

        if cmd.limit?
          throw new TypeError("limit must be a number") if isNaN(cmd.limit)

        curQuery.combine = cmd

      else
        throw new Error("unrecognizable command") unless typeof cmd is 'object'
        throw new Error("operation not defined") unless cmd.hasOwnProperty('operation')
        throw new Error("invalid operation") unless typeof cmd.operation is 'string'
        throw new Error("unknown operation '#{cmd.operation}'")

  condensed.push(curQuery)
  return condensed


# Clean segment - remove everything in the segment that starts with and underscore
exports.cleanProp = (prop) ->
  for key of prop
    if key[0] is '_'
      delete prop[key]
  return

exports.cleanSegments = cleanSegments = (segment) ->
  delete segment.parent
  delete segment._filter
  delete segment._raw

  prop = segment.prop
  for key of prop
    if key[0] is '_'
      delete prop[key]

  splits = segment.splits
  if splits
    for split in splits
      cleanSegments(split)

  return segment

createTabularHelper = (node, rangeFn, history) ->
  newHistory = {}
  for k, v of history
    newHistory[k] = v
  # Base case
  for k, v of node.prop
    v = rangeFn(v, k) if Array.isArray(v)
    newHistory[k] = v
  if node.splits?
    return flatten(node.splits.map((split) -> createTabularHelper(split, rangeFn, newHistory)))
  else
    return [newHistory]

exports.createTabular = createTabular = (node, rangeFn) ->
  rangeFn ?= (range) -> range
  return [] unless node.prop or node.splits
  return createTabularHelper(node, rangeFn, {})

class exports.Table
  constructor: ({root, @query}) ->
    @columns = createColumns(@query)
    # console.log root
    # console.log createTabular(root)
    @data = createTabular(root)
    @dimensionSize = @query.filter((op) -> op.operation is 'split').length
    @metricSize = @query.filter((op) -> op.operation is 'apply').length

  toTabular: (separator, rangeFn) ->
    _this = this
    header = @columns.map((column) -> return '\"' + column + '\"').join(separator)

    rangeFn or= (range) ->
      if range[0] instanceof Date
        range = range.map((range) -> range.toISOString())
      return range.join('-')

    content = @data.map((row) ->
      ret = []
      _this.columns.forEach((column, i) ->
        datum = row[column]
        if i < _this.dimensionSize
          if datum?
            if Array.isArray(datum)
              ret.push('\"' + rangeFn(datum).replace(/\"/, '\"\"') + '\"')
            else
              ret.push('\"' + datum.replace(/\"/, '\"\"') + '\"')
          else
            ret.push('\"\"')
        else
          if datum?
            ret.push('\"' + datum + '\"')
          else
            ret.push('\"0\"')
      )
      return ret.join(separator)
    ).join('\r\n')
    return header + '\r\n' + content

  columnMap: (mappingFunction) ->
    @data = @data.map((row) ->
      convertedRow = {}
      for k, v of row
        convertedRow[mappingFunction(k)] = row[k]

      return convertedRow
    )

    @columns = @columns.map(mappingFunction)
    return

exports.createColumns = createColumns = (query) ->
  split = flatten(query.filter((op) -> op.operation is 'split').map((op) ->
    if op.bucket is 'tuple'
      return op.splits.map((o) -> o.name)
    else
      return [op.name]
  ))
  tempApply = query.filter((op) -> op.operation is 'apply').map((op) -> op.name)
  apply = []
  for applyName in tempApply
    if apply.indexOf(applyName) >= 0
      apply.splice(apply.indexOf(applyName), 1)
    apply.push applyName
  return split.concat(apply)


filterTypePresedence = {
  'true': 1
  'false': 2
  'within': 3
  'is': 4
  'in': 5
  'fragments': 6
  'match': 7
  'not': 8
  'and': 9
  'or': 10
}

filterCompare = (filter1, filter2) ->
  typeDiff = filterTypePresedence[filter1.type] - filterTypePresedence[filter2.type]
  return typeDiff if typeDiff isnt 0 or filter1.type in ['not', 'and', 'or']
  return -1 if filter1.attribute < filter2.attribute
  return +1 if filter1.attribute > filter2.attribute

  # ToDo: expand this to all filters
  if filter1.type is 'is'
    return -1 if filter1.value < filter2.value
    return +1 if filter1.value > filter2.value

  return 0

rangesIntersect = (range1, range2) ->
  if range2[1] < range1[0] or range2[0] > range1[1]
    return false;
  else if range1[0] <= range2[1] and range2[0] <= range1[1]
    return true
  else
    return false


smaller = (a, b) -> if a < b then a else b
larger = (a, b) -> if a < b then b else a

mergeFilters = {
  "and": (filter1, filter2) ->
    return { type: 'false' } if filter1.type is 'false' or filter2.type is 'false'
    return filter2 if filter1.type is 'true'
    return filter1 if filter2.type is 'true'
    return unless filter1.type is filter2.type and filter1.attribute is filter2.attribute
    switch filter1.type
      when 'within'
        if rangesIntersect(filter1.range, filter2.range)
          [start1, end1] = filter1.range
          [start2, end2] = filter2.range
          return {
            type: 'within'
            attribute: filter1.attribute
            range: [larger(start1, start2), smaller(end1, end2)]
          }
        else
          return

      else
        return

  "or": (filter1, filter2) ->
    return { type: 'true' } if filter1.type is 'true' or filter2.type is 'true'
    return filter2 if filter1.type is 'false'
    return filter1 if filter2.type is 'false'
    return unless filter1.type is filter2.type and filter1.attribute is filter2.attribute
    switch filter1.type
      when 'within'
        if rangesIntersect(filter1.range, filter2.range)
          [start1, end1] = filter1.range
          [start2, end2] = filter2.range
          return {
            type: 'within'
            attribute: filter1.attribute
            range: [smaller(start1, start2), larger(end1, end2)]
          }
        else
          return { type: 'false' }

      else
        return
}


exports.upgradeFilter = upgradeFilter = (filter) ->
  throw new TypeError("must have filter") unless filter

  switch filter.type
    when 'true', 'false', 'in', 'is', 'fragments', 'match' then return filter

    when 'within'
      [r0, r1] = filter.range
      r0 = new Date(r0) if typeof r0 is 'string'
      r1 = new Date(r1) if typeof r1 is 'string'
      throw new TypeError("invalid range in 'within' filter") if isNaN(r0) or isNaN(r1)
      return {
        type: 'within'
        attribute: filter.attribute
        range: [r0, r1]
      }

    when 'not'
      return {
        type: 'not'
        filter: upgradeFilter(filter.filter)
      }

    when 'and', 'or'
      return {
        type: filter.type
        filters: filter.filters.map(upgradeFilter)
      }

    else
      throw new Error("unexpected filter type '#{type}'")

# Reduces a filter into a (potentially) simpler form the input is never modified
# Specifically this function:
# - flattens nested ANDs
# - flattens nested ORs
# - sorts lists of filters within an AND / OR by attribute
exports.simplifyFilter = simplifyFilter = (filter) ->
  throw new TypeError("must have filter") unless filter
  type = filter.type

  switch type
    when 'in'
      return if filter.values.length then filter else { type: 'false' }

    when 'true', 'false', 'is', 'fragments', 'match', 'within'
      return filter

    when 'not'
      switch filter.filter.type
        when 'true' then return { type: 'false' }
        when 'false' then return { type: 'true' }
        when 'not' then return simplifyFilter(filter.filter.filter)
        else return { type: 'not', filter: simplifyFilter(filter.filter) }

    when 'and', 'or'
      newFilters = []
      for f in filter.filters
        continue unless f?
        f = simplifyFilter(f)
        if f.type is type
          Array::push.apply(newFilters, f.filters)
        else
          newFilters.push(f)

      newFilters.sort(filterCompare)

      if newFilters.length > 1
        mergedFilters = []
        acc = newFilters[0]
        i = 1
        while i < newFilters.length
          currentFilter = newFilters[i]
          merged = mergeFilters[type](acc, currentFilter)
          if merged
            acc = merged
          else
            mergedFilters.push(acc)
            acc = currentFilter
          i++
        mergedFilters.push(acc)
        newFilters = mergedFilters

      switch newFilters.length
        when 0 then return { type: String(type is 'and') }
        when 1 then return newFilters[0]
        else return { type, filters: newFilters }

    else
      throw new Error("unexpected filter type '#{type}'")


orReduceFunction = (prev, now, index, all) ->
  if (index < all.length - 1)
    return prev + ', ' + now
  else
    return prev + ', or ' + now

andReduceFunction = (prev, now, index, all) ->
  if (index < all.length - 1)
    return prev + ', ' + now
  else
    return prev + ', and ' + now

exports.filterToString = filterToString = (filter) ->
  throw new TypeError("must have filter") unless filter

  switch filter.type
    when "true"
      return "Everything"
    when "false"
      return "Nothing"
    when "is"
      return "#{filter.attribute} is #{filter.value}"
    when "in"
      switch filter.values.length
        when 0 then return "Nothing"
        when 1 then return "#{filter.attribute} is #{filter.values[0]}"
        when 2 then return "#{filter.attribute} is either #{filter.values[0]} or #{filter.values[1]}"
        else return "#{filter.attribute} is one of: #{filter.values.reduce(orReduceFunction)}"
    when "fragments"
      return "#{filter.attribute} contains #{filter.fragments.map((fragment) -> return '\'' + fragment + '\'' )
        .reduce(andReduceFunction)}"
    when "match"
      return "#{filter.attribute} matches /#{filter.match}/"
    when "within"
      return "#{filter.attribute} is within #{filter.range[0]} and #{filter.range[1]}"
    when "not"
      return "not (#{filterToString(filter.filter)})"
    when "and"
      if filter.filters.length > 1
        return "#{filter.filters.map((filter) -> return '(' + filterToString(filter) + ')').join(' and ')}"
      else
        return "#{filterToString(filter.filters[0])}"
    when "or"
      if filter.filters.length > 1
        return "#{filter.filters.map((filter) -> return '(' + filterToString(filter) + ')').join(' or ')}"
      else
        return "#{filterToString(filter.filters[0])}"

  throw new TypeError('bad filter type')
  return


# Flattens the split tree into an array
#
# @param {SplitTree} root - the root of the split tree
# @param {prepend,append,none} order - what to do with the root of the tree
# @return {Array(SplitTree)} the tree nodes in the order specified

exports.flattenTree = (root, order) ->
  throw new TypeError('must have a tree') unless root
  throw new TypeError('order must be on of prepend, append, or none') unless order in ['prepend', 'append', 'none']
  flattenTreeHelper(root, order, result = [])
  return result

flattenTreeHelper = (root, order, result) ->
  result.push(root) if order is 'prepend'

  if root.splits
    for split in root.splits
      flattenTreeHelper(split, order, result)

  result.push(root) if order is 'append'
  return


# Adds parents to a split tree in place
#
# @param {SplitTree} root - the root of the split tree
# @param {SplitTree} parent [null] - the parent for the initial node
# @return {SplitTree} the input tree (with parent pointers)

exports.parentify = parentify = (root, parent = null) ->
  root.parent = parent
  if root.splits
    for split in root.splits
      parentify(split, root)
  return root


# Get filter from query

exports.getFilter = getFilter = (query) ->
  return if query[0]?.operation is 'filter' then query[0] else { type: 'true' }


# Separate filters into ones with a certain attribute and ones without
# Such that the WithoutFilter AND WithFilter are semantically equivalent to the original filter
#
# @param {FacetFilter} filter - the filter to separate
# @param {String} attribute - the attribute which to separate out
# @return {null|Array} null|[WithoutFilter, WithFilter] - the separated filters

exports.extractFilterByAttribute = extractFilterByAttribute = (filter, attribute) ->
  throw new TypeError("must have filter") unless filter
  throw new TypeError("must have attribute") unless typeof attribute is 'string'

  if filter is null
    return [null, null]

  if filter.type in ['true', 'false', 'is', 'in', 'fragments', 'match', 'within']
    if filter.type in ['true', 'false'] or filter.attribute isnt attribute
      return [filter]
    else
      return [{type: 'true'}, filter]

  if filter.type is 'not'
    return null unless filter.filter.type in ['true', 'false', 'is', 'in', 'fragments', 'match', 'within']
    if filter.filter.type is ['true', 'false'] or filter.filter.attribute isnt attribute
      return [filter]
    else
      return [{type: 'true'}, filter]

  if filter.type is 'or'
    hasNoClaim = (f) ->
      extract = extractFilterByAttribute(f, attribute)
      return extract and extract.length is 1

    return if filter.filters.every(hasNoClaim) then [filter] else null

  # filter.type is 'and'
  remainingFilters = []
  extractedFilters = []
  for f,i in filter.filters
    ex = extractFilterByAttribute(f, attribute)
    return null if ex is null
    remainingFilters.push(ex[0])
    extractedFilters.push(ex[1]) if ex.length > 1

  return [
    simplifyFilter({ type: 'and', filters: remainingFilters })
    simplifyFilter({ type: 'and', filters: extractedFilters })
  ]


isTimezone = (tz) ->
  return typeof tz is 'string' and tz.indexOf('/') isnt -1

exports.adjust = {
  second: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      if dt.getMilliseconds()
        dt.setMilliseconds(1000)
      return dt
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      dt.setMilliseconds(0)
      return dt
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      dt.setMilliseconds(Math.round(dt.getMilliseconds() / 1000 ) * 1000)
      return dt
  }
  minute: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      if dt.getMilliseconds() or dt.getSeconds()
        dt.setSeconds(60, 0)
      return dt
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      dt.setSeconds(0, 0)
      return dt
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      dt.setSeconds(Math.round(dt.getSeconds() / 60 ) * 60, 0)
      return dt
  }
  hour: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      if dt.getMilliseconds() or dt.getSeconds() or dt.getMinutes()
        dt.setMinutes(60, 0, 0)
      return new Date(dt.valueOf())
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      dt.setMinutes(0, 0, 0)
      return new Date(dt.valueOf())
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      dt.setMinutes(Math.round(dt.getMinutes() / 60 ) * 60, 0, 0)
      return new Date(dt.valueOf())
  }
  day: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      if dt.getMilliseconds() or dt.getSeconds() or dt.getMinutes() or dt.getHours()
        dt.setHours(24, 0, 0, 0)
      return new Date(dt.valueOf())
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      dt.setHours(0, 0, 0, 0)
      return new Date(dt.valueOf())
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      dt.setHours(Math.round(dt.getHours() / 60 ) * 60, 0, 0, 0)
      return new Date(dt.valueOf())
  }
}

exports.convertToTimezoneJS = (timerange, timezone) ->
  return timerange.map((time) -> new timezoneJS.Date(time, timezone))

# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
