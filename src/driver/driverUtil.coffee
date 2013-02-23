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



exports.flatten = (ar) -> Array::concat.apply([], ar)

# ===================================

# group the queries steps in to the logical queries that will need to be done
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
    split: null
    applies: []
    combine: null
  }
  condensed = []
  for cmd in query
    switch cmd.operation
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
        throw new Error("Can not have more than one combine") if curQuery.combine
        curQuery.combine = cmd

      else
        throw new Error("Unknown operation '#{cmd.operation}'")

  condensed.push(curQuery)
  return condensed


# -----------------------------------------------------
# Handle commonJS crap
if typeof module is 'undefined' then window['driverUtil'] = exports else module.exports = exports
