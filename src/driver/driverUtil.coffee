rq = (module) ->
  if typeof window is 'undefined'
    return require(module)
  else
    moduleParts = module.split('/')
    return window[moduleParts[moduleParts.length - 1]]

#async = rq('async')

if typeof exports is 'undefined'
  exports = {}

# -----------------------------------------------------


# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (ar) -> Array::concat.apply([], ar)


# Group the queries steps in to the logical queries that will need to be done
# output: [
#   {
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
  condensed = []
  for cmd in query
    switch cmd.operation
      when 'filter'
        throw new Error("can not have more than on filter") if curQuery.filter
        curQuery.filter = cmd

      when 'split'
        condensed.push(curQuery)
        curQuery = {
          split: cmd
          applies: []
          combine: null
        }

      when 'apply'
        curQuery.applies.push(cmd)

      when 'combine'
        throw new Error("can not have more than one combine") if curQuery.combine
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

createTabular = (node, history) ->
  newHistory = {}
  for k, v of history
    newHistory[k] = v
  # Base case
  for k, v of node.prop
    newHistory[k] = v
  if node.splits?
    return flatten(node.splits.map((split) -> createTabular(split, newHistory)))
  else
    return [newHistory]

stripProp = (splits, columns) ->
  data = splits.map((split) -> return columns.map((column) -> split[column] or null))
  return data

class exports.Table
  constructor: ({root, @query}) ->
    @columns = createColumns(@query)
    # console.log root
    # console.log createTabular(root)
    @data = stripProp(createTabular(root, {}), @columns)
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
      row.forEach((datum, i) ->
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
if typeof module is 'undefined' then window['driverUtil'] = exports else module.exports = exports
