{specialJoin, find, dummyObject} = require('./common')
{FacetFilter} = require('./filter')
{FacetOptions} = require('./options')

DEFAULT_DATASET = 'main'

class FacetApply
  operation: 'apply'

  constructor: ({dataset, operands}, datasetContext, dummy) ->
    throw new TypeError("can not call `new FacetApply` directly use FacetApply.fromSpec instead") unless dummy is dummyObject

    datasetContext or= DEFAULT_DATASET
    if dataset and datasetContext isnt DEFAULT_DATASET and dataset isnt datasetContext
      throw new Error("dataset conflict between '#{datasetContext}' and '#{dataset}'")

    dataset or= datasetContext
    if operands
      throw new TypeError("operands must be an array of length 2") unless Array.isArray(operands) and operands.length is 2
      @operands = if operands[0] instanceof FacetApply then operands else operands.map((op) -> applyFromSpec(op, dataset))
      seenDataset = {}
      for operand in @operands
        for ds in operand.getDatasets()
          seenDataset[ds] = 1
      @datasets = Object.keys(seenDataset).sort()
    else
      @dataset = dataset

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

  _addNameToString: (str) ->
    return str unless @name
    return "#{@name} <- #{str}"

  _datasetOrNothing: ->
    return if @dataset is DEFAULT_DATASET then '' else @dataset

  _datasetWithAttribute: ->
    return if @dataset is DEFAULT_DATASET then @attribute else "#{@dataset}@#{@attribute}"

  toString: ->
    return @_addNameToString("base apply")

  toHash: ->
    throw new Error('can not call this directly')

  valueOf: (datasetContext) ->
    applySpec = {}
    applySpec.name = @name if @name
    applySpec.filter = @filter.valueOf() if @filter
    applySpec.options = @options.valueOf() if @options
    if @arithmetic
      myDataset = if @datasets.length is 1 then @datasets[0] else null
      applySpec.arithmetic = @arithmetic
      applySpec.operands = @operands.map((op) -> op.valueOf(myDataset))
      applySpec.dataset = myDataset if myDataset and myDataset isnt datasetContext and myDataset isnt DEFAULT_DATASET
    else
      applySpec.aggregate = @aggregate
      applySpec.dataset = @dataset if @dataset and @dataset isnt datasetContext and @dataset isnt DEFAULT_DATASET
    return applySpec

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    return false unless other
    if @operands
      return @arithmetic is other.arithmetic and
             @operands.every((op, i) -> op.isEqual(other.operands[i]))
    else
      return @aggregate is other.aggregate and
             @attribute is other.attribute and
             @dataset is other.dataset and
             Boolean(@filter) is Boolean(other.filter) and
             (not @filter or @filter.isEqual(other.filter)) and
             Boolean(@options) is Boolean(other.options) and
             (not @options or @options.isEqual(other.options))

  isAdditive: ->
    return false

  addName: (name) ->
    applySpec = @valueOf()
    applySpec.name = name
    return FacetApply.fromSpec(applySpec)

  getDataset: ->
    if @operands
      return @datasets[0]
    else
      return @dataset

  getDatasets: ->
    if @operands
      return @datasets
    else
      return [@dataset]

  getAttributes: ->
    attributeCollection = {}
    @_collectAttributes(attributeCollection)
    attributes = []
    attributes.push(k) for k, v of attributeCollection
    attributes.sort()
    return attributes

  _collectAttributes: (attributes) ->
    if @operands
      @operands[0]._collectAttributes(attributes)
      @operands[1]._collectAttributes(attributes)
    else
      attributes[@attribute] = 1 if @attribute
    return


class ConstantApply extends FacetApply
  constructor: ({name, @aggregate, value, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @dataset = null
    @name = name if name
    @options = new FacetOptions(options) if options
    @_ensureAggregate('constant')
    @_verifyName()
    value = Number(value) if typeof value is 'string'
    throw new Error("constant apply must have a numeric value") if typeof value isnt 'number' or isNaN(value)
    @value = value

  toString: ->
    return @_addNameToString(String(@value))

  toHash: ->
    hashStr = "C:#{@value}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.value = @value
    return apply

  isEqual: (other, compareSegmentFilter) ->
    return super and @value is other.value

  isAdditive: ->
    return true

  getDatasets: ->
    return []


class CountApply extends FacetApply
  constructor: ({name, @aggregate, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('count')
    @_verifyName()

  toString: ->
    return @_addNameToString("count()")

  toHash: ->
    hashStr = "CT#{@_datasetOrNothing()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  isAdditive: ->
    return true



class SumApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('sum')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("#{@aggregate}(`#{@attribute}`)")

  toHash: ->
    hashStr = "SM:#{@_datasetWithAttribute()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    return apply

  isAdditive: ->
    return true



class AverageApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('average')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("#{@aggregate}(`#{@attribute}`)")

  toHash: ->
    hashStr = "AV:#{@_datasetWithAttribute()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    return apply

  decomposeAverage: ->
    return new DivideApply({
      name: @name
      dataset: @dataset
      operands: [
        { aggregate: 'sum', attribute: @attribute }
        { aggregate: 'count' }
      ]
    })


class MinApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('min')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("#{@aggregate}(`#{@attribute}`)")

  toHash: ->
    hashStr = "MN:#{@_datasetWithAttribute()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    return apply



class MaxApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('max')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("#{@aggregate}(`#{@attribute}`)")

  toHash: ->
    hashStr = "MX:#{@_datasetWithAttribute()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    return apply



class UniqueCountApply extends FacetApply
  constructor: ({name, @aggregate, @attribute, filter, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @filter = FacetFilter.fromSpec(filter) if filter
    @options = new FacetOptions(options) if options
    @_ensureAggregate('uniqueCount')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("#{@aggregate}(`#{@attribute}`)")

  toHash: ->
    hashStr = "UC:#{@_datasetWithAttribute()}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    return apply



class QuantileApply extends FacetApply
  constructor: ({name, @attribute, @quantile, options}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @options = new FacetOptions(options) if options
    throw new TypeError("quantile must be a number") unless typeof @quantile is 'number'
    throw new Error("quantile must be between 0 and 1 (is: #{@quantile})") unless 0 <= @quantile <= 1
    @_ensureAggregate('quantile')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addNameToString("quantile(#{@attribute}, #{@quantile})")

  toHash: ->
    hashStr = "QT:#{@attribute}:#{@quantile}"
    hashStr += '/' + @filter.toHash() if @filter
    return hashStr

  valueOf: ->
    apply = super
    apply.attribute = @attribute
    apply.quantile = @quantile
    return apply

  isEqual: (other, compareSegmentFilter) ->
    return super and @quantile is other.quantile

  isAdditive: ->
    return true



class AddApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('add')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} + #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addNameToString(expr)

  toHash: ->
    return "#{@operands[0].toHash()}+#{@operands[1].toHash()}"

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class SubtractApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('subtract')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} - #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from in ['divide', 'multiply']
    return @_addNameToString(expr)

  toHash: ->
    return "#{@operands[0].toHash()}-#{@operands[1].toHash()}"

  isAdditive: ->
    return @operands[0].isAdditive() and @operands[1].isAdditive()



class MultiplyApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('multiply')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} * #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addNameToString(expr)

  toHash: ->
    return "#{@operands[0].toHash()}*#{@operands[1].toHash()}"

  isAdditive: ->
    return (
      (@operands[0] instanceof ConstantApply and @operands[1].isAdditive()) or
      (@operands[0].isAdditive() and @operands[1] instanceof ConstantApply)
    )



class DivideApply extends FacetApply
  constructor: ({name, @arithmetic, @operands}, datasetContext) ->
    super(arguments[0], datasetContext, dummyObject)
    @name = name if name
    @_verifyName()
    @_ensureArithmetic('divide')

  toString: (from = 'add') ->
    expr = "#{@operands[0].toString(@arithmetic)} / #{@operands[1].toString(@arithmetic)}"
    expr = "(#{expr})" if from is 'divide'
    return @_addNameToString(expr)

  toHash: ->
    return "#{@operands[0].toHash()}/#{@operands[1].toHash()}"

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

applyFromSpec = (applySpec, datasetContext) ->
  return applySpec if applySpec instanceof FacetApply
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
  return new ApplyConstructor(applySpec, datasetContext)

FacetApply.fromSpec = (applySpec) ->
  return applyFromSpec(applySpec)


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

