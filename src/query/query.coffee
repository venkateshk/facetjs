
class FacetQuery
  constructor: (commands) ->
    @groups = [{
      split: null
      applies: []
      combine: null
    }]
    if Array.isArray(commands)
      commands = commands.slice()
      if commands[0].operation is 'filter'
        @filter = FacetFilter.fromSpec(commands.shift())
      else
        @filter = new TrueFilter()

      for command in commands
        switch command.operation
          when 'filter' then throw new Error("filter not allowed here")

          when 'split'
            @groups.push {
              split: FacetSplit.fromSpec(command)
              applies: []
              combine: null
            }

          when 'apply'
            curGroup = @groups[@groups.length - 1]
            curGroup.applies.push(FacetApply.fromSpec(command))

          when 'combine'
            curGroup = @groups[@groups.length - 1]
            throw new Error("can not have multiple combines") if curGroup.combine
            curGroup.combine = FacetCombine.fromSpec(command)

          else
            throw new Error("unrecognizable command") unless typeof command is 'object'
            throw new Error("operation not defined") unless command.hasOwnProperty('operation')
            throw new Error("invalid operation") unless typeof command.operation is 'string'
            throw new Error("unknown operation '#{command.operation}'")

  toString: ->
    return "FacetQuery"

  valueOf: ->
    arr = []

    if @filter not instanceof TrueFilter
      filterVal = @filter.valueOf()
      filterVal.operation = 'filter'
      arr.push filterVal

    for {split, applies, combine} in @groups
      if split
        splitVal = split.valueOf()
        splitVal.operation = 'split'
        arr.push splitVal

      for apply in applies
        applyVal = apply.valueOf()
        applyVal.operation = 'apply'
        arr.push applyVal

      if combine
        combineVal = combine.valueOf()
        combineVal.operation = 'combine'
        arr.push combineVal

    return arr

# Export!
exports.FacetQuery = FacetQuery



