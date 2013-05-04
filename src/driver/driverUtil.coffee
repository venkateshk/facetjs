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

exports.cleanSegment = (segment) ->
  for key of segment
    if key[0] is '_'
      delete segment[key]

  prop = segment.prop
  for key of prop
    if key[0] is '_'
      delete prop[key]
  return

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
