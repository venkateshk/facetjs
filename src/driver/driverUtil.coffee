`(typeof window === 'undefined' ? {} : window)['driverUtil'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------

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

# Filter and map
exports.filterMap = (array, fn) ->
  ret = []
  for a in array
    v = fn(a)
    continue if typeof v is 'undefined'
    ret.push(v)
  return ret

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
  is: ({prop, value}) ->
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
        curQuery.filter = cmd

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

# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
