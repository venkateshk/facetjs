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

# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['driverUtil'] = exports else module.exports = exports
