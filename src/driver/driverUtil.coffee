`(typeof window === 'undefined' ? {} : window)['driverUtil'] = (function(module, require){"use strict"; var exports = module.exports`
# -----------------------------------------------------

# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (ar) ->
  flatAr = []
  ar.forEach((item) ->
    if Array.isArray(item)
      arrayExists = true
      item.forEach((subItem) ->
        flatAr.push subItem
      )
      return
    flatAr.push item
  )
  ar = flatAr

  return ar

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
  return [] unless node?.prop
  return createTabularHelper(node, rangeFn, {})

class exports.Table
  constructor: ({root, query}) ->
    @query = query.valueOf()
    @columns = createColumns(@query)
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