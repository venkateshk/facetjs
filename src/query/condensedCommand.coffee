"use strict"

{FacetSplit, ParallelSplit} = require('./split')
{FacetCombine, SliceCombine} = require('./combine')

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
    return @knownProps[@getCombine().sort.prop]

  getSortHash: ->
    {sort, direction} = @getCombine()
    return "#{@knownProps[sort.prop].toHash()}##{sort.direction}"

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


exports.CondensedCommand = CondensedCommand
