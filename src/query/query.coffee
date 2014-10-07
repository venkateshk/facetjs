"use strict"

{isInstanceOf} = require('../util')
{specialJoin, getValueOf, find, dummyObject} = require('./common')
{FacetDataset} = require('./dataset')
{FacetFilter, TrueFilter, AndFilter} = require('./filter')
{FacetSplit, ParallelSplit} = require('./split')
{FacetApply} = require('./apply')
{FacetCombine} = require('./combine')
{CondensedCommand} = require('./condensedCommand')

class FacetQuery
  constructor: (commands) ->
    throw new TypeError("query spec must be an array") unless Array.isArray(commands)
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
      @filter = FacetFilter.fromJS(command)
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
          split = FacetSplit.fromJS(command)
          for dataset in split.getDatasets()
            throw new Error("split dataset '#{dataset}' is not defined") unless hasDataset[dataset]

          curGroup = new CondensedCommand()
          curGroup.setSplit(split)
          @condensedCommands.push(curGroup)

        when 'apply'
          apply = FacetApply.fromJS(command)
          throw new Error("base apply must have a name") unless apply.name
          datasets = apply.getDatasets()
          for dataset in datasets
            throw new Error("apply dataset '#{dataset}' is not defined") unless hasDataset[dataset]
          curGroup.addApply(apply)

        when 'combine'
          curGroup.setCombine(FacetCombine.fromJS(command))

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

  getFiltersByDataset: (extraFilter) ->
    extraFilter or= new TrueFilter()
    throw new TypeError("extra filter should be a FacetFilter") unless isInstanceOf(extraFilter, FacetFilter)
    commonFilter = new AndFilter([@getFilter(), extraFilter]).simplify()
    filtersByDataset = {}
    for dataset in @datasets
      filtersByDataset[dataset.name] = new AndFilter([commonFilter, dataset.getFilter()]).simplify()
    return filtersByDataset

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

  getApplies: ->
    applies = []
    for condensedCommand in @condensedCommands
      for apply in condensedCommand.applies
        alreadyListed = find(applies, (existingApply) ->
          return existingApply.name is apply.name and existingApply.isEqual(apply)
        )
        continue if alreadyListed
        applies.push(apply)
    return applies

  getCombines: ->
    combines = @condensedCommands.map(({combine}) -> combine)
    combines.shift()
    return combines

# Export!
exports.FacetQuery = FacetQuery

