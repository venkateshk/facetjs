"use strict"

{isInstanceOf} = require('../util')

dummyObject = {}

isInterger = (n) ->
  return not isNaN(n) and n % 1 is 0

isPositiveInterger = (n) ->
  return isInterger(n) and 0 < n

repeatString = (string, times) ->
  return '' unless times > 0
  return new Array(times + 1).join(string)

class AttributeMeta
  constructor: ({@type}, dummy) ->
    throw new TypeError("can not call `new AttributeMeta` directly use AttributeMeta.fromSpec instead") unless dummy is dummyObject

  _ensureType: (attributeMetaType) ->
    if not @type
      @type = attributeMetaType # Set the type if it is so far undefined
      return
    if @type isnt attributeMetaType
      throw new TypeError("incorrect attributeMeta `type` '#{@type}' (needs to be: '#{attributeMetaType}')")
    return

  valueOf: ->
    return {
      @type
    }

  serialize: (value) ->
    return value


class DefaultAttributeMeta extends AttributeMeta
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('default')


class LargeAttributeMeta extends AttributeMeta
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('large')


class RangeAttributeMeta extends AttributeMeta
  constructor: ({@separator, @rangeSize, @digitsBeforeDecimal, @digitsAfterDecimal}) ->
    super(arguments[0], dummyObject)
    @_ensureType('range')
    @separator or= ';'
    throw new TypeError('`separator` must be a non-empty string') unless typeof @separator is 'string' and @separator.length
    throw new TypeError('`rangeSize` must be a number') unless typeof @rangeSize is 'number'
    if @rangeSize > 1
      throw new Error("`rangeSize` greater than 1 must be an integer") unless isInterger(@rangeSize)
    else
      throw new Error("`rangeSize` less than 1 must divide 1") unless isInterger(1 / @rangeSize)

    if @digitsBeforeDecimal?
      throw new Error("`digitsBeforeDecimal` must be a positive integer") unless isPositiveInterger(@digitsBeforeDecimal)
    else
      @digitsBeforeDecimal = false

    if @digitsAfterDecimal?
      throw new Error("`digitsAfterDecimal` must be a positive integer") unless isPositiveInterger(@digitsAfterDecimal)
      digitsInSize = (String(@rangeSize).split('.')[1] or '').length
      if @digitsAfterDecimal < digitsInSize
        throw new Error("`digitsAfterDecimal` must be at least #{digitsInSize} to accommodate for a `rangeSize` of #{@rangeSize}")
    else
      @digitsAfterDecimal = false

  valueOf: ->
    attributeMetaSpec = super()
    attributeMetaSpec.separator = @separator unless @separator is ';'
    attributeMetaSpec.rangeSize = @rangeSize
    attributeMetaSpec.digitsBeforeDecimal = @digitsBeforeDecimal unless @digitsBeforeDecimal is false
    attributeMetaSpec.digitsAfterDecimal = @digitsAfterDecimal unless @digitsAfterDecimal is false
    return attributeMetaSpec

  _serializeNumber: (value) ->
    return '' if value is null
    value = String(value)
    return value unless @digitsBeforeDecimal or @digitsAfterDecimal
    [before, after] = value.split('.')
    if @digitsBeforeDecimal
      before = repeatString('0', @digitsBeforeDecimal - before.length) + before

    if @digitsAfterDecimal
      after or= ''
      after += repeatString('0', @digitsAfterDecimal - after.length)

    value = before
    value += ".#{after}" if after
    return value

  serialize: (range) ->
    return null unless Array.isArray(range) and range.length is 2
    return @_serializeNumber(range[0]) + @separator + @_serializeNumber(range[1])


class UniqueAttributeMeta extends AttributeMeta
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('unique')

  serialize: ->
    throw new Error("can not serialize an approximate unique value")


class HistogramAttributeMeta extends AttributeMeta
  constructor: ->
    super(arguments[0] or {}, dummyObject)
    @_ensureType('histogram')

  serialize: ->
    throw new Error("can not serialize a histogram value")


# Make lookup
attributeMetaConstructorMap = {
  default: DefaultAttributeMeta
  large: LargeAttributeMeta
  range: RangeAttributeMeta
  unique: UniqueAttributeMeta
  historgram: HistogramAttributeMeta
}


AttributeMeta.fromSpec = (attributeMetaSpec) ->
  return attributeMetaSpec if isInstanceOf(attributeMetaSpec, AttributeMeta)
  if attributeMetaSpec.type is 'range' and attributeMetaSpec.size # Back compat.
    attributeMetaSpec.rangeSize = attributeMetaSpec.size

  throw new Error("unrecognizable attributeMeta") unless typeof attributeMetaSpec is 'object'
  throw new Error("type must be defined") unless attributeMetaSpec.hasOwnProperty('type')
  throw new Error("type must be a string") unless typeof attributeMetaSpec.type is 'string'
  FilterConstructor = attributeMetaConstructorMap[attributeMetaSpec.type]
  throw new Error("unsupported attributeMeta type '#{attributeMetaSpec.type}'") unless FilterConstructor
  return new FilterConstructor(attributeMetaSpec)

AttributeMeta.default = new DefaultAttributeMeta()


# Export!
module.exports = {
  AttributeMeta
  DefaultAttributeMeta
  LargeAttributeMeta
  RangeAttributeMeta
  UniqueAttributeMeta
  HistogramAttributeMeta
}
