# Group the queries steps in to the logical queries that will need to be done

addSplitName = (split, name) ->
  splitSpec = split.valueOf()
  splitSpec.name = name
  return FacetSplit.fromSpec(splitSpec)

class CondensedCommand
  constructor: ->
    @knownProps = {}
    @split = null
    @applies = []
    @combine = null

  setSplit: (split) ->
    throw new Error("split already defined") if @split
    @split = split
    @knownProps[split.name] = split if split.name
    return

  addApply: (apply) ->
    @applies.push(apply)
    @knownProps[apply.name] = apply

  setCombine: (combine) ->
    throw new Error("combine called without split") unless @split
    throw new Error("can not combine more than once") if @combine
    if combine.sort and not @knownProps[combine.sort.prop]
      throw new Error("sort on unknown prop '#{combine.sort.prop}'")
    @combine = combine
    return

  getDatasets: ->
    return @split.getDatasets() if @split
    datasets = []
    for apply in @applies
      applyDatasets = apply.getDatasets()
      for dataset in applyDatasets
        continue if dataset in datasets
        datasets.push(dataset)
    return datasets

  getSplit: ->
    return @split

  getEffectiveSplit: ->
    return @split if not @split or @split.bucket isnt 'parallel'
    sortBy = @getSortBy()
    return @split if sortBy instanceof FacetSplit
    # if here then sortBy is instanceof FacetApply

    sortDatasets = sortBy.getDatasets()
    effectiveSplits = @split.splits.filter((split) -> split.getDataset() in sortDatasets)
    switch effectiveSplits.length
      when 0
        return @split.splits[0] # This should not happen unless we are sorting by constant
      when 1
        return addSplitName(effectiveSplits[0], @split.name)
      else
        return new ParallelSplit({
          name: @split.name
          splits: effectiveSplits
          segmentFilter: @split.segmentFilter
        })

  getApplies: ->
    return @applies

  getCombine: ->
    return @combine if @combine
    if @split
      return new SliceCombine({ sort: { compare: 'natural', prop: @split.name, direction: 'ascending' } })
    else
      return null

  getSortBy: ->
    combine = @getCombine()
    return null unless combine?.sort
    return @knownProps[combine.sort.prop]

  getZeroProp: ->
    zeroProp = {}
    zeroProp[apply.name] = 0 for apply in @applies
    return zeroProp

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

    # Backwards compatible
    if commands.length and commands[0].datasets
      newCommands = commands[0].datasets.map((datasetName) -> {
        operation: 'dataset'
        name: datasetName
        source: 'base'
      })
      newCommandsMap = {}
      for newCommand in newCommands
        newCommandsMap[newCommand.name] = newCommand
      i = 1
      while commands[i].operation is 'filter' and commands[i].dataset
        newCommandsMap[commands[i].dataset].filter = commands[i]
        i++
      commands = newCommands.concat(commands.slice(i))
    # /Backwards compatible


    i = 0
    numCommands = commands.length

    # Parse dataset operation
    @datasets = []
    while i < numCommands
      command = commands[i]
      break unless command.operation is 'dataset'
      @datasets.push(new FacetDataset(command))
      i++

    if @datasets.length is 0
      @datasets.push(FacetDataset.base)

    # Parse filter
    @filter = null
    if i < numCommands and commands[i].operation is 'filter'
      @filter = FacetFilter.fromSpec(command)
      i++

    hasDataset = {}
    for dataset in @datasets
      hasDataset[dataset.name] = true

    # Parse split apply combines
    @condensedCommands = [new CondensedCommand()]
    while i < numCommands
      command = commands[i]
      curGroup = @condensedCommands[@condensedCommands.length - 1]

      switch command.operation
        when 'dataset', 'filter'
          throw new Error("#{command.operation} not allowed here")

        when 'split'
          split = FacetSplit.fromSpec(command)
          for dataset in split.getDatasets()
            throw new Error("split dataset '#{dataset}' is not defined") unless hasDataset[dataset]

          curGroup = new CondensedCommand()
          curGroup.setSplit(split)
          @condensedCommands.push(curGroup)

        when 'apply'
          apply = FacetApply.fromSpec(command)
          throw new Error("base apply must have a name") unless apply.name
          datasets = apply.getDatasets()
          for dataset in datasets
            throw new Error("apply dataset '#{dataset}' is not defined") unless hasDataset[dataset]
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

    if not (@datasets.length is 1 and @datasets[0] is FacetDataset.base)
      for dataset in @datasets
        datasetSpec = dataset.valueOf()
        datasetSpec.operation = 'dataset'
        spec.push(datasetSpec)

    if @filter
      filterSpec = @filter.valueOf()
      filterSpec.operation = 'filter'
      spec.push(filterSpec)

    for condensedCommand in @condensedCommands
      condensedCommand.appendToSpec(spec)

    return spec

  toJSON: -> @valueOf.apply(this, arguments)

  getDatasets: ->
    return @datasets

  getDatasetFilter: (datasetName) ->
    for dataset in @datasets
      return dataset.getFilter() if dataset.name is datasetName
    return null

  getFilter: ->
    return @filter or new TrueFilter()

  getFilterComplexity: ->
    complexity = @getFilter().getComplexity()
    complexity += dataset.getFilter().getComplexity() for dataset in @datasets
    return complexity

  getCondensedCommands: ->
    return @condensedCommands

  getSplits: ->
    splits = @condensedCommands.map(({split}) -> split)
    splits.shift()
    return splits


# Export!
exports.CondensedCommand = CondensedCommand
exports.FacetQuery = FacetQuery

