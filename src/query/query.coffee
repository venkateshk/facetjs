# Group the queries steps in to the logical queries that will need to be done
class FacetGroup
  constructor: ->
    @split = null
    @splits = []
    @applies = []
    @combine = null

  setSplit: (split) ->
    throw new Error("split already defined")
    @split = split
    return

  addApply: (apply) ->
    @applies.push(apply)

  setCombine: (combine) ->
    throw new Error("combine called without split") unless @splits.length
    throw new Error("can not combine more than once") if @combine
    @combine = combine
    return

  getSplit: ->
    return @splits[0] or null

  appendToSpec: (spec) ->
    if @split
      splitVal = @split.valueOf()
      splitVal.operation = 'split'
      spec.push(splitVal)

    for apply in @applies
      applyVal = apply.valueOf()
      applyVal.operation = 'apply'
      spec.push(applyVal)

    if @combine
      combineVal = @combine.valueOf()
      combineVal.operation = 'combine'
      spec.push(combineVal)

    return


class FacetQuery
  constructor: (commands) ->
    throw new TypeError("query spec must be an array") unless Array.isArray(commands)

    i = 0
    numCommands = commands.length

    # Parse dataset operation
    if i < numCommands
      command = commands[i]
      if command.operation is 'dataset'
        @datasets = command.datasets
        i++

    @datasets = ['main'] unless @datasets

    # Parse filters
    @filters = []
    while i < numCommands
      command = commands[i]
      break if command.operation isnt 'filter'
      filter = FacetFilter.fromSpec(command)
      dataset = filter.getDataset()
      throw new Error("filter dataset '#{dataset}' is not defined") unless dataset in @datasets
      @filters.push(filter)
      i++

    # Parse split apply combines
    @groups = [new FacetGroup()]
    while i < numCommands
      command = commands[i]
      curGroup = @groups[@groups.length - 1]

      switch command.operation
        when 'dataset', 'filter'
          throw new Error("#{command.operation} not allowed here")

        when 'split'
          split = FacetSplit.fromSpec(command)
          dataset = split.getDataset()
          throw new Error("split dataset '#{dataset}' is not defined") unless dataset in @datasets
          curGroup = new FacetGroup()
          curGroup.setSplit(split)
          @groups.push(curGroup)

        when 'apply'
          apply = FacetApply.fromSpec(command)
          throw new Error("base apply must have a name") unless apply.name
          datasets = apply.getDatasets()
          for dataset in datasets
            throw new Error("apply dataset '#{dataset}' is not defined") unless dataset in @datasets
          curGroup.addApply(apply)

        when 'combine'
          curGroup.setCombine(FacetCombine.fromSpec(command))

        else
          throw new Error("unrecognizable command") unless typeof command is 'object'
          throw new Error("operation not defined") unless command.hasOwnProperty('operation')
          throw new Error("invalid operation") unless typeof command.operation is 'string'
          throw new Error("unknown operation '#{command.operation}'")

      i++


  toString: ->
    return "FacetQuery"

  valueOf: ->
    spec = []

    for filter in @filters
      filterVal = filter.valueOf()
      filterVal.operation = 'filter'
      spec.push(filterVal)

    for group in @groups
      group.appendToSpec(spec)

    return spec

  toJSON: @::valueOf

  getFilter: ->
    return @filters[0] or new TrueFilter()

  getGroups: ->
    return @groups

  getSplits: ->
    splits = @groups.map(({split}) -> split)
    splits.shift()
    return splits


# Export!
exports.FacetQuery = FacetQuery

