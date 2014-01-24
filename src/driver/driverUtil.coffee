{ FacetQuery } = require('../query')

# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (xss) ->
  flat = []
  for xs in xss
    throw new TypeError('bad value in list') unless Array.isArray(xs)
    for x in xs
      flat.push(x)

  return flat

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


exports.attributesFromApplies = (applies) ->
  seenAttribute = {}

  extractAttribute = (apply) ->
    if apply.attribute
      seenAttribute[apply.attribute] = true
    else
      apply.operands.forEach(extractAttribute)
    return

  applies.forEach(extractAttribute)
  attributes = []
  for attribute, v of seenAttribute
    attributes.push(attribute)

  return attributes


# Converts dates to intervals
dateToIntervalPart = (date) ->
  return date.toISOString()
    .replace('Z',    '') # remove Z
    .replace('.000', '') # millis if 0
    .replace(/:00$/, '') # remove seconds if 0
    .replace(/:00$/, '') # remove minutes if 0
    .replace(/T00$/, '') # remove hours if 0

exports.datesToInterval = datesToInterval = (start, end) ->
  return "#{dateToIntervalPart(start)}/#{dateToIntervalPart(end)}"


# Converts a time filter to an array of intervals
exports.timeFilterToIntervals = (filter, forceInterval) ->
  if filter.type is 'true'
    throw new Error("must have an interval") if forceInterval
    return ["1000-01-01/3000-01-01"]

  ors = if filter.type is 'or' then filter.filters else [filter]
  return ors.map ({type, attribute, range}) ->
    throw new Error("can only time filter with a 'within' filter") unless type is 'within'
    return datesToInterval(range[0], range[1])


# Generates a string that represents the flooring expression given a flooring function (string)
exports.continuousFloorExpresion = ({variable, floorFn, size, offset}) ->
  expr = variable
  expr = "#{expr} - #{offset}" if offset isnt 0
  expr = "(#{expr})" if offset isnt 0 and size isnt 1
  expr = "#{expr} / #{size}" if size isnt 1
  expr = "#{floorFn}(#{expr})"
  expr = "#{expr} * #{size}" if size isnt 1
  expr = "#{expr} + #{offset}" if offset isnt 0
  return expr


# Finds an element in array that matches fn
exports.find = (array, fn) ->
  for a, i in array
    return a if fn.call(array, a, i)
  return null


# Filter and map (how is this method not part of native JS?!)
# Maps the `array` according to `fn` and removes the elements that return `undefined`
#
# @param {Array} array, the array to filter
# @param {Function} fn, the function to filter on
# @return {Array} the mapped (and filtered) array
exports.filterMap = (array, fn) ->
  ret = []
  for a in array
    v = fn(a)
    continue if typeof v is 'undefined'
    ret.push(v)
  return ret


# Join all the given rows together into a single row
#
# @param {Array(Object)} rows, the rows to merge
# @return {Object} the joined rows
exports.joinRows = joinRows = (rows) ->
  newRow = {}
  for row in rows
    for prop, value of row
      newRow[prop] = value
  return newRow


# Join several arrays of results
exports.joinResults = (splitNames, applyNames, results) ->
  return results[0] if results.length <= 1
  return [joinRows(results.map((result) -> result[0]))] if splitNames.length is 0
  zeroRow = {}
  zeroRow[name] = 0 for name in applyNames
  mapping = {}
  for result in results
    continue unless result # skip any null result (is this right?)
    for row in result
      key = splitNames.map((splitName) -> row[splitName]).join(']#;{#')
      mapping[key] = [zeroRow] unless mapping[key]
      mapping[key].push(row)

  joinResult = []
  joinResult.push(joinRows(rows)) for ket, rows of mapping
  return joinResult


# Clean segment - remove everything in the segment that starts with and underscore
exports.cleanProp = (prop) ->
  for key of prop
    if key[0] is '_'
      delete prop[key]
  return


exports.cleanSegments = cleanSegments = (segment) ->
  delete segment.parent
  delete segment._filtersByDataset
  delete segment._raws

  prop = segment.prop
  for key of prop
    if key[0] is '_'
      delete prop[key]

  splits = segment.splits
  if splits
    for split in splits
      cleanSegments(split)

  return segment


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


# Flattens the split tree into an array
#
# @param {SplitTree} root - the root of the split tree
# @param {prepend,append,none} order - what to do with the root of the tree
# @return {Array(SplitTree)} the tree nodes in the order specified

exports.flattenTree = flattenTree = (root, order) ->
  throw new TypeError('must have a tree') unless root
  throw new TypeError('order must be on of prepend, append, or none') unless order in ['prepend', 'append', 'none']
  flattenTreeHelper(root, order, result = [])
  return result

flattenTreeHelper = (root, order, result) ->
  result.push(root) if order is 'prepend' or not root.splits

  if root.splits
    for split in root.splits
      flattenTreeHelper(split, order, result)

  result.push(root) if order is 'append'
  return


# Creates a flat list of props

exports.createTabular = createTabular = (root, order, rangeFn) ->
  throw new TypeError('must have a tree') unless root
  order ?= 'none'
  throw new TypeError('order must be on of prepend, append, or none') unless order in ['prepend', 'append', 'none']
  rangeFn ?= (range) -> range
  return [] unless root?.prop
  createTabularHelper(root, order, rangeFn, {}, result = [])
  return result

createTabularHelper = (root, order, rangeFn, context, result) ->
  myProp = {}
  for k, v of context
    myProp[k] = v

  for k, v of root.prop
    v = rangeFn(v) if Array.isArray(v)
    myProp[k] = v

  result.push(myProp) if order is 'prepend' or not root.splits

  if root.splits
    for split in root.splits
      createTabularHelper(split, order, rangeFn, myProp, result)

  result.push(myProp) if order is 'append'
  return


csvEscape = (str) -> '"' + String(str).replace(/\"/g, '\"\"') + '"'

class exports.Table
  constructor: ({root, query, columnName}) ->
    throw new TypeError('query must be a FacetQuery') unless query instanceof FacetQuery
    @query = query
    @columnName = columnName or (op) -> op.name
    @splitColumns = flatten(query.getSplits().map((split) ->
      return if split.bucket is 'tuple' then split.splits else [split]
    ))
    @applyColumns = query.getApplies()
    @data = createTabular(root)

  toTabular: (separator, lineBreak, rangeFn) ->
    header = []
    header.push(csvEscape(@columnName(column))) for column in @splitColumns
    header.push(csvEscape(@columnName(column))) for column in @applyColumns
    header = header.join(separator)

    rangeFn or= (range) ->
      if range[0] instanceof Date
        range = range.map((range) -> range.toISOString())
      return range.join('-')

    lines = @data.map(((row) ->
      line = []
      for column in @splitColumns
        datum = row[column.name] or ''
        line.push(if Array.isArray(datum) then csvEscape(rangeFn(datum)) else csvEscape(datum))

      for column in @applyColumns
        datum = row[column.name] or 0
        line.push(csvEscape(datum))

      return line.join(separator)

    ), this)

    return header + lineBreak + lines.join(lineBreak)

  columnMap: (columnName) ->
    @columnName = columnName
    return


