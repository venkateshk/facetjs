
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

  toString: ->
    return "base apply"

  valueOf: ->
    throw new Error("base apply has no value")

  isAdditive: ->
    return false



class ConstantApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if typeof arg is 'number'
        @value = arg
      else
        { @aggregate, @value } = arg
    else if arguments.length isnt 0
      throwBadArgs()



    @_ensureAggregate('constant')

  toString: ->
    return String(@value)

  valueOf: ->
    return { aggregate: @aggregate, value: @value }

  isAdditive: ->
    return true



class CountApply extends FacetApply
  constructor: ->
    if arguments.length is 1
      { @aggregate } = arguments[0]
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('count')

  toString: ->
    return "count()"

  valueOf: ->
    return { aggregate: @aggregate }

  isAdditive: ->
    return true



class SumApply extends FacetApply
  constructor: (arg) ->
    switch arguments.length
      when 1
        if typeof arg isnt 'string'
          { @aggregate, @attribute } = arguments[0]
        else
          [@attribute] = arguments
      when 2
        if typeof arguments[1] is 'string'
          [@name, @attribute] = arguments
        else
          [@attribute, @options] = arguments
      when 3
        [@name, @attribute, @options] = arguments
      else
        throwBadArgs()
    @_ensureAggregate('sum')

  toString: ->
    return "#{@aggregate}(#{@attribute})"

  valueOf: ->
    return { aggregate: @aggregate, attribute: @attribute }

  isAdditive: ->
    return true



class AverageApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if typeof arg is 'String'
        @attribute = arg
      else
        { @aggregate, @attribute } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('average')

  toString: ->
    return "#{@aggregate}(#{@attribute})"

  valueOf: ->
    return { aggregate: @aggregate, attribute: @attribute }



class MinApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if typeof arg is 'String'
        @attribute = arg
      else
        { @aggregate, @attribute } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('min')

  toString: ->
    return "#{@aggregate}(#{@attribute})"

  valueOf: ->
    return { aggregate: @aggregate, attribute: @attribute }



class MaxApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if typeof arg is 'String'
        @attribute = arg
      else
        { @aggregate, @attribute } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('max')

  toString: ->
    return "#{@aggregate}(#{@attribute})"

  valueOf: ->
    return { aggregate: @aggregate, attribute: @attribute }



class UniqueCountApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if typeof arg is 'String'
        @attribute = arg
      else
        { @aggregate, @attribute } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureAggregate('uniqueCount')

  toString: ->
    return "#{@aggregate}(#{@attribute})"

  valueOf: ->
    return { aggregate: @aggregate, attribute: @attribute }



class QuantileApply extends FacetApply
  constructor: ->
    if arguments.length is 1
      { @type, @attribute, @quantile, @options } = arguments[0]
    else if arguments.length in [2, 3]
      [@attribute, @quantile, @options] = arguments
    else
      throwBadArgs()
    @_ensureAggregate('quantile')

  toString: ->
    return "quantile(#{@attribute}, #{@quantile})"

  valueOf: ->
    apply = { aggregate: @aggregate, attribute: @attribute, quantile: @quantile }
    apply.options = @options if @options
    return apply

  isAdditive: ->
    return true



class AddApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if Array.isArray(arg)
        @operands = arg
      else
        { @aggregate, @operands } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureArithmetic('add')

  toString: ->
    return "(#{@operands[0]}) + (#{@operands[1]})"

  valueOf: ->
    return { arithmetic: @arithmetic, operands: @operands }

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class SubtractApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if Array.isArray(arg)
        @operands = arg
      else
        { @aggregate, @operands } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureArithmetic('subtract')

  toString: ->
    return "(#{@operands[0]}) - (#{@operands[1]})"

  valueOf: ->
    return { arithmetic: @arithmetic, operands: @operands }

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class MultiplyApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if Array.isArray(arg)
        @operands = arg
      else
        { @aggregate, @operands } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureArithmetic('multiply')

  toString: ->
    return "(#{@operands[0]}) * (#{@operands[1]})"

  valueOf: ->
    return { arithmetic: @arithmetic, operands: @operands }

  isAdditive: ->
    return (
      (@operands[0] instanceof ConstantApply and @operands[1].isAdditive()) or
      (@operands[0].isAdditive() and @operands[1] instanceof ConstantApply)
    )



class DivideApply extends FacetApply
  constructor: (arg) ->
    if arguments.length is 1
      if Array.isArray(arg)
        @operands = arg
      else
        { @aggregate, @operands } = arg
    else if arguments.length isnt 0
      throwBadArgs()
    @_ensureArithmetic('divide')

  toString: ->
    return "(#{@operands[0]}) / (#{@operands[1]})"

  valueOf: ->
    return { arithmetic: @arithmetic, operands: @operands }

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

