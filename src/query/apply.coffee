
class FacetApply
  constructor: ({dataset}, dummy) ->
    throw new TypeError("can not call `new FacetApply` directly use FacetApply.fromSpec instead") unless dummy is dummyObject
    @dataset = dataset if dataset

  _ensureAggregate: (aggregate) ->
    if not @aggregate
      @aggregate = aggregate # Set the aggregate if it is so far undefined
      return
    if @aggregate isnt aggregate
      throw new TypeError("incorrect apply aggregate '#{@aggregate}' (needs to be: '#{aggregate}')")
    return

  _ensureArithmetic: (arithmetic) ->
    if not @arithmetic
      @arithmetic = arithmetic # Set the arithmetic if it is so far undefined
      return
    if @arithmetic isnt arithmetic
      throw new TypeError("incorrect apply arithmetic '#{@arithmetic}' (needs to be: '#{arithmetic}')")
    return

  _verifyName: ->
    return unless @name
    throw new TypeError("apply name must be a string") unless typeof @name is 'string'

  _verifyAttribute: ->
    throw new TypeError("attribute must be a string") unless typeof @attribute is 'string'

  _verifyOperands: ->
    throw new TypeError("operands must be an array of length 2") unless Array.isArray(@operands) and @operands.length is 2

  _addName: (str) ->
    return str unless @name
    return "#{@name} <- #{str}"

  toString: ->
    return @_addName("base apply")

  valueOf: ->
    apply = {}
    apply.name = @name if @name
    apply.dataset = @dataset if @dataset
    apply.filter = @filter.valueOf() if @filter
    apply.options = @options.valueOf() if @options
    return apply

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    return Boolean(other) and
           @aggregate is other.aggregate and
           @arithmetic is other.arithmetic and
           @attribute is other.attribute and
           Boolean(@filter) is Boolean(other.filter) and
           (not @filter or @filter.isEqual(other.filter))
           Boolean(@options) is Boolean(other.options) and
           (not @options or @options.isEqual(other.options))

  isAdditive: ->
    return false

  getDataset: ->
    return @dataset or 'main'

  getDatasets: ->
    return [@getDataset()] unless @operands
    datasets = @operands[0].getDatasets()
    for dataset in @operands[1].getDatasets()
      datasets.push(dataset) unless dataset in datasets
    return datasets


class ConstantApply extends FacetApply
  constructor: ({name, @aggregate, @value, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @options = new FacetOptions(options) if options
    @_ensureAggregate('constant')
    @_verifyName()

  toString: ->
    return @_addName(String(@value))

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.value = @value
    return apply

  isEqual: (other, compareSegmentFilter) ->
    return super and @value is other.value

  isAdditive: ->
    return true

  getDataset: ->
    return null

  getDatasets: ->
    return []


class CountApply extends FacetApply
  constructor: ({name, @aggregate, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('count')
    @_verifyName()

  toString: ->
    return @_addName("count()")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    return apply

  isAdditive: ->
    return true



class SumApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('sum')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    return apply

  isAdditive: ->
    return true



class AverageApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('average')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    return apply



class MinApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('min')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    return apply



class MaxApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('max')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    return apply



class UniqueCountApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('uniqueCount')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    return apply



class QuantileApply extends FacetApply
  constructor: ({name, @attribute, @quantile, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @options = new FacetOptions(options) if options
    throw new TypeError("quantile must be a number") unless typeof @quantile is 'number'
    throw new Error("quantile must be between 0 and 1 (is: #{@quantile})") unless 0 <= @quantile <= 1
    @_ensureAggregate('quantile')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("quantile(#{@attribute}, #{@quantile})")

  valueOf: ->
    apply = super
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.quantile = @quantile
    return apply

  isEqual: (other, compareSegmentFilter) ->
    return super and @quantile is other.quantile

  isAdditive: ->
    return true



class AddApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('add')
    @_verifyOperands()
    @operands = @operands.map(FacetApply.fromSpec)

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} + #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = super
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isEqual: (other) ->
    return super and @operands.every((op, i) -> op.isEqual(other.operands[i]))

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class SubtractApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('subtract')
    @_verifyOperands()
    @operands = @operands.map(FacetApply.fromSpec)

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} - #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = super
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isEqual: (other) ->
    return super and @operands.every((op, i) -> op.isEqual(other.operands[i]))

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class MultiplyApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('multiply')
    @_verifyOperands()
    @operands = @operands.map(FacetApply.fromSpec)

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} * #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = super
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isEqual: (other) ->
    return super and @operands.every((op, i) -> op.isEqual(other.operands[i]))

  isAdditive: ->
    return (
      (@operands[0] instanceof ConstantApply and @operands[1].isAdditive()) or
      (@operands[0].isAdditive() and @operands[1] instanceof ConstantApply)
    )



class DivideApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('divide')
    @_verifyOperands()
    @operands = @operands.map(FacetApply.fromSpec)

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} / #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = super
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isEqual: (other) ->
    return super and @operands.every((op, i) -> op.isEqual(other.operands[i]))

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1] instanceof ConstantApply


# Segregator

jsPostProcessorScheme = {
  constant: ({value}) -> return -> value

  getter: ({name}) -> (prop) -> prop[name]

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
        throw new Error('unknown arithmetic')

  finish: (name, getter) -> (prop) ->
    prop[name] = getter(prop)
    return
}

addApplyName = (apply, name) ->
  applySpec = apply.valueOf()
  applySpec.name = name
  return FacetApply.fromSpec(applySpec)

class ApplySegregator
  constructor: (@postProcessorScheme) ->
    @byDataset = {}
    @postProcess = []
    @nameIndex = 0

  getNextName: ->
    @nameIndex++
    return "_N_" + @nameIndex

  addSingleDatasetApply: (apply, track) ->
    if apply.aggregate is 'constant'
      return @postProcessorScheme.constant(apply)

    dataset = apply.getDataset()
    apply = addApplyName(apply, @getNextName()) if not apply.name
    @byDataset[dataset] or= []

    existingApplyGetter = find(@byDataset[dataset], (ag) -> ag.apply.isEqual(apply))

    if not existingApplyGetter
      getter = @postProcessorScheme.getter(apply)
      @byDataset[dataset].push(existingApplyGetter = { apply, getter })

    if track
      @trackApplySegmentation.push({ dataset, applyName: existingApplyGetter.apply.name })

    return existingApplyGetter.getter

  addMultiDatasetApply: (apply, track) ->
    [op1, op2] = apply.operands
    op1Datasets = op1.getDatasets()
    op2Datasets = op2.getDatasets()
    getter1 = if op1Datasets.length <= 1 then @addSingleDatasetApply(op1, track) else @addMultiDatasetApply(op1, track)
    getter2 = if op2Datasets.length <= 1 then @addSingleDatasetApply(op2, track) else @addMultiDatasetApply(op2, track)
    return @postProcessorScheme.arithmetic(apply.arithmetic, getter1, getter2)

  addApplies: (applies, trackApplyName) ->
    @trackApplySegmentation = if trackApplyName then [] else null

    # First add all the simple applies then add the multi-dataset applies
    # This greatly simplifies the logic in the addSingleDatasetApply function because it never have to
    # substitute an apply with a temp name with one that has a permanent name

    multiDatasetApplies = []
    for apply in applies
      applyName = apply.name
      switch apply.getDatasets().length
        when 0
          getter = @addSingleDatasetApply(apply, applyName is trackApplyName)
          @postProcess.push(@postProcessorScheme.finish(applyName, getter))
        when 1
          @addSingleDatasetApply(apply, applyName is trackApplyName)
        else
          multiDatasetApplies.push(apply)

    multiDatasetApplies.forEach(((apply) ->
      applyName = apply.name
      getter = @addMultiDatasetApply(apply, applyName is trackApplyName)
      @postProcess.push(@postProcessorScheme.finish(applyName, getter))
    ), this)

    return @trackApplySegmentation

  getAppliesByDataset: ->
    appliesByDataset = {}
    for dataset, applyGetters of @byDataset
      appliesByDataset[dataset] = applyGetters.map((d) -> d.apply)
    return appliesByDataset

  getPostProcessors: ->
    return @postProcess


# Segregate (split up) potentially multi-dataset applies into their component datasets
#
# @param {Array(Apply)} applies, the list of applies to segregate
# @param {String} trackApplyName, the name of the apply to single out (optional)
FacetApply.segregate = (applies, trackApplyName = null, postProcessorScheme = jsPostProcessorScheme) ->
  applySegregator = new ApplySegregator(postProcessorScheme)
  trackedSegregation = applySegregator.addApplies(applies, trackApplyName)

  return {
    appliesByDataset: applySegregator.getAppliesByDataset()
    postProcessors: applySegregator.getPostProcessors()
    trackedSegregation
  }

# Make lookup
applyAggregateConstructorMap = {
  "constant": ConstantApply
  "count": CountApply
  "sum": SumApply
  "average": AverageApply
  "min": MinApply
  "max": MaxApply
  "uniqueCount": UniqueCountApply
  "quantile": QuantileApply
}

applyArithmeticConstructorMap = {
  "add": AddApply
  "subtract": SubtractApply
  "multiply": MultiplyApply
  "divide": DivideApply
}

FacetApply.fromSpec = (applySpec) ->
  throw new Error("unrecognizable apply") unless typeof applySpec is 'object'
  if applySpec.hasOwnProperty('aggregate')
    throw new Error("aggregate must be a string") unless typeof applySpec.aggregate is 'string'
    ApplyConstructor = applyAggregateConstructorMap[applySpec.aggregate]
    throw new Error("unsupported aggregate '#{applySpec.aggregate}'") unless ApplyConstructor
  else if applySpec.hasOwnProperty('arithmetic')
    throw new Error("arithmetic must be a string") unless typeof applySpec.arithmetic is 'string'
    ApplyConstructor = applyArithmeticConstructorMap[applySpec.arithmetic]
    throw new Error("unsupported arithmetic '#{applySpec.arithmetic}'") unless ApplyConstructor
  else
    throw new Error("must have an aggregate or arithmetic")
  return new ApplyConstructor(applySpec)


# Export!
exports.FacetApply = FacetApply
exports.ConstantApply = ConstantApply
exports.CountApply = CountApply
exports.SumApply = SumApply
exports.AverageApply = AverageApply
exports.MinApply = MinApply
exports.MaxApply = MaxApply
exports.UniqueCountApply = UniqueCountApply
exports.QuantileApply = QuantileApply
exports.AddApply = AddApply
exports.SubtractApply = SubtractApply
exports.MultiplyApply = MultiplyApply
exports.DivideApply = DivideApply

