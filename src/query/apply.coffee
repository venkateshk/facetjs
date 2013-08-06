
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

  _initSimpleAggregator: (args) ->
    argsLength = args.length
    if args[argsLength - 1] instanceof FacetOptions
      argsLength--
      @options = args[argsLength]

    switch argsLength
      when 1
        if typeof args[0] isnt 'string'
          { @name, @aggregate, @attribute, options } = args[0]
          @options = new FacetOptions(options) if options
        else
          [@attribute] = args

      when 2
        [@name, @attribute] = args

      else
        throwBadArgs()

    return

  _initArithmetic: (args) ->
    switch args.length
      when 1
        if not Array.isArray(args[0])
          { @name, @arithmetic, @operands } = args[0]
          @operands = @operands.map(FacetApply.fromSpec)
        else
          [@operands] = args

      when 2
        [@name, @operands] = args

      else
        throwBadArgs()

    throw new Error("must have two operands got #{@operands.length}") unless @operands.length is 2
    return

  _addName: (str) ->
    return str unless @name
    return "#{@name} <- #{str}"

  toString: ->
    return @_addName("base apply")

  valueOf: ->
    throw new Error("base apply has no value")

  isAdditive: ->
    return false



class ConstantApply extends FacetApply
  constructor: ({@name, @aggregate, @value, options}) ->
    @options = new FacetOptions(options) if options
    @_ensureAggregate('constant')

  toString: ->
    return @_addName(String(@value))

  valueOf: ->
    apply = { aggregate: @aggregate, value: @value }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return true



class CountApply extends FacetApply
  constructor: ->
    argsLength = args.length
    if args[argsLength - 1] instanceof FacetOptions
      argsLength--
      @options = args[argsLength]

    if arguments.length is 1
      { @aggregate } = arguments[0]
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('count')

  toString: ->
    return @_addName("count()")

  valueOf: ->
    apply = { aggregate: @aggregate }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return true



class SumApply extends FacetApply
  constructor: ->
    @_initSimpleAggregator(arguments)
    @_ensureAggregate('sum')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return true



class AverageApply extends FacetApply
  constructor: (arg) ->
    @_initSimpleAggregator(arguments)
    @_ensureAggregate('average')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute }
    apply.name = @name if @name
    return apply



class MinApply extends FacetApply
  constructor: (arg) ->
    @_initSimpleAggregator(arguments)
    @_ensureAggregate('min')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute }
    apply.name = @name if @name
    return apply



class MaxApply extends FacetApply
  constructor: (arg) ->
    @_initSimpleAggregator(arguments)
    @_ensureAggregate('max')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute }
    apply.name = @name if @name
    return apply



class UniqueCountApply extends FacetApply
  constructor: (arg) ->
    @_initSimpleAggregator(arguments)
    @_ensureAggregate('uniqueCount')

  toString: ->
    return @_addName("#{@aggregate}(#{@attribute})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute }
    apply.name = @name if @name
    return apply



class QuantileApply extends FacetApply
  constructor: ->
    argsLength = args.length
    if args[argsLength - 1] instanceof FacetOptions
      argsLength--
      @options = args[argsLength]

    switch argsLength
      when 1
        if typeof arguments[0] isnt 'string'
          { @name, @attribute, @quantile, options } = arguments[0]
          @options = new FacetOptions(options) if options
        else
          throwBadArgs()

      when 2
        [@attribute, @quantile] = arguments

      when 3
        [@name, @attribute, @quantile] = arguments

      else
        throwBadArgs()
    @_ensureAggregate('quantile')

  toString: ->
    return @_addName("quantile(#{@attribute}, #{@quantile})")

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute, quantile: @quantile }
    apply.name = @name if @name
    apply.options = @options if @options
    return apply

  isAdditive: ->
    return true



class AddApply extends FacetApply
  constructor: ->
    @_initArithmetic(arguments)
    @_ensureArithmetic('add')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} + #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = { arithmetic: @arithmetic, operands: @operands.map(getValueOf) }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class SubtractApply extends FacetApply
  constructor: ->
    @_initArithmetic(arguments)
    @_ensureArithmetic('subtract')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} - #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addName(expr)

  valueOf: ->
    apply = { arithmetic: @arithmetic, operands: @operands.map(getValueOf) }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class MultiplyApply extends FacetApply
  constructor: ->
    @_initArithmetic(arguments)
    @_ensureArithmetic('multiply')

  toString: ->
    expr = "#{@operands[0].toString(@arithmetic)} * #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = { arithmetic: @arithmetic, operands: @operands.map(getValueOf) }
    apply.name = @name if @name
    return apply

  isAdditive: ->
    return (
      (@operands[0] instanceof ConstantApply and @operands[1].isAdditive()) or
      (@operands[0].isAdditive() and @operands[1] instanceof ConstantApply)
    )



class DivideApply extends FacetApply
  constructor: ->
    @_initArithmetic(arguments)
    @_ensureArithmetic('divide')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} / #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addName(expr)

  valueOf: ->
    apply = { arithmetic: @arithmetic, operands: @operands.map(getValueOf) }
    apply.name = @name if @name
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

