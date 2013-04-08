# this needs to be done in JS land to avoid creating a global var module
`
if (typeof window !== 'undefined') {
  exports = {};
  module = { exports: exports };
  require = function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  }
}
`

# -----------------------------------------------------

# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (ar) -> Array::concat.apply([], ar)


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
        throw new Error("can not have more than on filter") if curQuery.filter
        curQuery.filter = cmd

      when 'split'
        condensed.push(curQuery)
        throw new Error("split must have name") unless cmd.name
        throw new TypeError("invalid name in split") unless typeof cmd.name is 'string'
        curQuery = {
          split: cmd
          applies: []
          combine: null
        }
        curKnownProps = {}
        curKnownProps[cmd.name] = true

      when 'apply'
        throw new Error("apply must have name") unless cmd.name
        throw new TypeError("invalid name in apply") unless typeof cmd.name is 'string'
        curQuery.applies.push(cmd)
        curKnownProps[cmd.name] = true

      when 'combine'
        throw new Error("can not have more than one combine") if curQuery.combine
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
        throw new Error("unknown operation '#{cmd.operation}'")

  condensed.push(curQuery)
  return condensed


# Clean segment - remove everything in the segment that starts with and underscore
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
  split = query.filter((op) -> op.operation is 'split').map((op) -> op.name)
  tempApply = query.filter((op) -> op.operation is 'apply').map((op) -> op.name)
  apply = []
  for applyName in tempApply
    if apply.indexOf(applyName) >= 0
      apply.splice(apply.indexOf(applyName), 1)
    apply.push applyName
  return split.concat(apply)

# -----------------------------------------------------
# Handle commonJS crap
window['driverUtil'] = module.exports if typeof window isnt 'undefined'
