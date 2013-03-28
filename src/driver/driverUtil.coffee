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
exports.flatten = (ar) -> Array::concat.apply([], ar)


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

collectSplits = (node) ->
  if node.splits?
    return Array::concat.apply([], node.splits.map(collectSplits))
  else
    return node.prop

stripProp = (splits) ->
  columns = _.unique(Array::concat.apply([], splits.map((split) -> return _.keys(split))))
  data = splits.map((split) -> return columns.map((column) -> split[column] or null))
  return {columns, data}

exports.createMatrix = (node) ->
  return stripProp(collectSplits(node))

exports.createCSVFromMatrix = ({columns, data}) ->
  header = columns.map((column) -> return '\"' + column + '\"').join(',')
  content = data.map((row) ->
    return row.map((datum) ->
      if datum?
        return '\"' + datum + '\"'
      else
        return '\"0\"'
    ).join(',')
  ).join('\r\n')
  return header + '\r\n' + content

# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['driverUtil'] = exports else module.exports = exports
