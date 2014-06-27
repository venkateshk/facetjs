"use strict"

{find} = require('./common')

jsPostProcessorScheme = {
  constant: ({value}) ->
    return -> value

  getter: ({name}) ->
    return (prop) -> prop[name]

  arithmetic: (arithmetic, lhs, rhs) ->
    return switch arithmetic
      when 'add'
        (prop) -> lhs(prop) + rhs(prop)
      when 'subtract'
        (prop) -> lhs(prop) - rhs(prop)
      when 'multiply'
        (prop) -> lhs(prop) * rhs(prop)
      when 'divide'
        (prop) -> rv = rhs(prop); if rv is 0 then 0 else lhs(prop) / rv
      else
        throw new Error("Unknown arithmetic '#{arithmetic}'")

  finish: (name, getter) -> (prop) ->
    prop[name] = getter(prop)
    return
}


class ApplySimplifier
  constructor: ({@postProcessorScheme, @namePrefix, @topLevelConstant, @breakToSimple, @breakAverage} = {}) ->
    @postProcessorScheme or= jsPostProcessorScheme
    @namePrefix or= '_S'
    @topLevelConstant or= 'process'
    @breakToSimple ?= false
    @breakAverage ?= false

    @seperateApplyGetters = []
    @postProcess = []
    @nameIndex = 0

  _getNextName: (sourceApplyName) ->
    @nameIndex++
    return "#{@namePrefix}#{@nameIndex}_#{sourceApplyName}"

  _addBasicApply: (apply, sourceApplyName) ->
    if apply.aggregate is 'constant'
      return @postProcessorScheme.constant(apply)

    if apply.aggregate is 'average' and @breakAverage
      return @_addArithmeticApply(apply.decomposeAverage(), sourceApplyName)

    if apply.name
      myApplyGetter = {
        apply
        getter: @postProcessorScheme.getter(apply)
        sourceApplyNames: {}
      }
      @seperateApplyGetters.push(myApplyGetter)
    else
      apply = apply.addName(@_getNextName(sourceApplyName))
      myApplyGetter = find(@seperateApplyGetters, (ag) -> ag.apply.isEqual(apply))
      if not myApplyGetter
        myApplyGetter = {
          apply
          getter: @postProcessorScheme.getter(apply)
          sourceApplyNames: {}
        }
        @seperateApplyGetters.push(myApplyGetter)

    myApplyGetter.sourceApplyNames[sourceApplyName] = 1
    return myApplyGetter.getter

  _addArithmeticApply: (apply, sourceApplyName) ->
    [op1, op2] = apply.operands
    lhs = if op1.arithmetic then @_addArithmeticApply(op1, sourceApplyName) else @_addBasicApply(op1, sourceApplyName)
    rhs = if op2.arithmetic then @_addArithmeticApply(op2, sourceApplyName) else @_addBasicApply(op2, sourceApplyName)
    return @postProcessorScheme.arithmetic(apply.arithmetic, lhs, rhs)

  _addSingleDatasetApply: (apply, sourceApplyName) ->
    if apply.aggregate is 'constant'
      return @postProcessorScheme.constant(apply)

    if @breakToSimple
      if apply.aggregate is 'average' and @breakAverage
        apply = apply.decomposeAverage()

      if apply.arithmetic
        return @_addArithmeticApply(apply, sourceApplyName)
      else
        return @_addBasicApply(apply, sourceApplyName)

    else
      return @_addBasicApply(apply, sourceApplyName)

  _addMultiDatasetApply: (apply, sourceApplyName) ->
    [op1, op2] = apply.operands
    op1Datasets = op1.getDatasets()
    op2Datasets = op2.getDatasets()
    lhs = if op1Datasets.length <= 1 then @_addSingleDatasetApply(op1, sourceApplyName) else @_addMultiDatasetApply(op1, sourceApplyName)
    rhs = if op2Datasets.length <= 1 then @_addSingleDatasetApply(op2, sourceApplyName) else @_addMultiDatasetApply(op2, sourceApplyName)
    return @postProcessorScheme.arithmetic(apply.arithmetic, lhs, rhs)

  addApplies: (applies) ->
    # First add all the simple applies then add the multi-dataset applies
    # This greatly simplifies the logic in the _addSingleDatasetApply function because it never have to
    # substitute an apply with a temp name with one that has a permanent name

    multiDatasetApplies = []
    for apply in applies
      applyName = apply.name
      switch apply.getDatasets().length
        when 0
          getter = @postProcessorScheme.constant(apply)
          switch @topLevelConstant
            when 'process'
              @postProcess.push(@postProcessorScheme.finish(applyName, getter))

            when 'leave'
              @seperateApplyGetters.push {
                apply
                getter
                sourceApplyName: applyName
              }

            when 'ignore' then null

            else throw new Error('unknown topLevelConstant')

        when 1
          getter = @_addSingleDatasetApply(apply, applyName)
          if @breakToSimple and (apply.arithmetic or (apply.aggregate is 'average' and @breakAverage))
            @postProcess.push(@postProcessorScheme.finish(applyName, getter))

        else
          multiDatasetApplies.push(apply)

    for apply in multiDatasetApplies
      applyName = apply.name
      getter = @_addMultiDatasetApply(apply, applyName)
      @postProcess.push(@postProcessorScheme.finish(applyName, getter))

    return this

  getSimpleApplies: ->
    return @seperateApplyGetters
      .map(({apply}) -> apply)

  getSimpleAppliesByDataset: ->
    appliesByDataset = {}
    for {apply} in @seperateApplyGetters
      dataset = apply.getDataset()
      appliesByDataset[dataset] or= []
      appliesByDataset[dataset].push(apply)
    return appliesByDataset

  getPostProcessors: ->
    return @postProcess

  getApplyComponents: (applyName) ->
    return @seperateApplyGetters
      .filter(({sourceApplyNames}) -> sourceApplyNames[applyName])
      .map(({apply}) -> apply)


exports.ApplySimplifier = ApplySimplifier
