
class FacetApply
  constructor: ->
    return

  _ensureAggregate: (applyAggregate) ->
    if not @aggregate
      @aggregate = applyAggregate # Set the aggregate if it is so far undefined
      return
    if @aggregate isnt applyAggregate
      throw new TypeError("incorrect apply aggregate '#{@aggregate}' (needs to be: '#{applyAggregate}')")
    return

  _ensureArithmetic: (applyArithmetic) ->
    if not @arithmetic
      @arithmetic = applyArithmetic # Set the arithmetic if it is so far undefined
      return
    if @arithmetic isnt applyArithmetic
      throw new TypeError("incorrect apply arithmetic '#{@arithmetic}' (needs to be: '#{applyArithmetic}')")
    return

  _addName: (str) ->
    return str unless @name
    return "#{@name} <- #{str}"

  toString: ->
    return @_addName("base apply")

  valueOf: ->
    apply = {}
    apply.name = @name if @name
    apply.options = @options.valueOf() if @options
    return apply

  isAdditive: ->
    return false



class ConstantApply extends FacetApply
  constructor: ({name, @aggregate, @value, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @_ensureAggregate('constant')

  toString: ->
    return @_addName(String(@value))

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.value = @value
    apply.filter = @filter.valueOf() if @filter
    return apply

  isAdditive: ->
    return true



class CountApply extends FacetApply
  constructor: ({name, @aggregate, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('count')

  toString: ->
    return @_addName("count()")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.filter = @filter.valueOf() if @filter
    return apply

  isAdditive: ->
    return true



class SumApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('sum')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.filter = @filter.valueOf() if @filter
    return apply

  isAdditive: ->
    return true



class AverageApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('average')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.filter = @filter.valueOf() if @filter
    return apply



class MinApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('min')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.filter = @filter.valueOf() if @filter
    return apply



class MaxApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('max')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.filter = @filter.valueOf() if @filter
    return apply



class UniqueCountApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}) ->
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('uniqueCount')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.filter = @filter.valueOf() if @filter
    return apply



class QuantileApply extends FacetApply
  constructor: ({name, @attribute, @quantile, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @_ensureAggregate('quantile')

  toString: ->
    return @_addName("quantile(#{@attribute}, #{@quantile})")

  valueOf: ->
    apply = super.valueOf()
    apply.aggregate = @aggregate
    apply.attribute = @attribute
    apply.quantile = @quantile
    return apply

  isAdditive: ->
    return true



class AddApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    @name = name if name
    @operands = @operands.map(FacetApply.fromSpec)
    @_ensureArithmetic('add')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} + #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = super.valueOf()
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class SubtractApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    @name = name if name
    @operands = @operands.map(FacetApply.fromSpec)
    @_ensureArithmetic('subtract')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} - #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = super.valueOf()
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class MultiplyApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    @name = name if name
    @operands = @operands.map(FacetApply.fromSpec)
    @_ensureArithmetic('multiply')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} * #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = super.valueOf()
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isAdditive: ->
    return (
      (@operands[0] instanceof ConstantApply and @operands[1].isAdditive()) or
      (@operands[0].isAdditive() and @operands[1] instanceof ConstantApply)
    )



class DivideApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}) ->
    @name = name if name
    @operands = @operands.map(FacetApply.fromSpec)
    @_ensureArithmetic('divide')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} / #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = super.valueOf()
    apply.arithmetic = @arithmetic
    apply.operands = @operands.map(getValueOf)
    return apply

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1] instanceof ConstantApply



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
  if applySpec.aggregate
    ApplyConstructor = applyAggregateConstructorMap[applySpec.aggregate]
    throw new Error("unsupported aggregate #{applySpec.aggregate}") unless ApplyConstructor
  else if applySpec.arithmetic
    ApplyConstructor = applyArithmeticConstructorMap[applySpec.arithmetic]
    throw new Error("unsupported arithmetic #{applySpec.arithmetic}") unless ApplyConstructor
  else
    throw new Error("must have an arithmetic or attribute")
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

