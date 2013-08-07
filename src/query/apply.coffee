
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

  _verifyName: ->
    return unless @name
    throw new TypeError("apply name must be a string") unless typeof @name is 'string'

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    throw new TypeError("quantile must be a number") unless typeof @quantile is 'number'
    throw new Error("quantile must be between 0 and 1 (is: #{@quantile})") unless 0 <= @quantile <= 1
    @_ensureAggregate('quantile')
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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
    @_verifyName()

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

