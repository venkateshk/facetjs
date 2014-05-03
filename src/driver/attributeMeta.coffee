isInterger = (n) ->
  return n % 1 is 0

repeatString = (string, times) ->
  return '' unless times > 0
  return new Array(times + 1).join(string)

class AttributeMeta
  constructor: ({@type}) ->
    throw new TypeError("can not call `new AttributeMeta` directly use AttributeMeta.fromSpec instead")

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


class RangeAttributeMeta extends AttributeMeta
  constructor: ({@separator, @rangeSize, @digitsBeforeDecimal, @digitsAfterDecimal}) ->
    super(arguments[0])
    @_ensureType('range')
    @separator or= ';'
    throw new TypeError('`separator` must be a non-empty string') unless typeof @separator is 'string' and @separator.length
    throw new TypeError('`rangeSize` must be a number') unless typeof @rangeSize is 'number'
    if @rangeSize > 1
      throw new Error("`rangeSize` greater than 1 must be an integer") unless isInterger(@rangeSize)
    else
      throw new Error("`rangeSize` less than 1 must divide 1") unless isInterger(1 / @rangeSize)
    @digitsBeforeDecimal ?= false
    @digitsAfterDecimal ?= false

  valueOf: ->
    attributeMetaSpec = super()
    attributeMetaSpec.separator = @separator unless @separator is ';'
    attributeMetaSpec.rangeSize = @rangeSize
    attributeMetaSpec.digitsBeforeDecimal = @digitsBeforeDecimal unless @digitsBeforeDecimal is false
    attributeMetaSpec.digitsAfterDecimal = @digitsAfterDecimal unless @digitsAfterDecimal is false
    return attributeMetaSpec

  _valueToDatabase: (value) ->
    return '' if value is null
    value = String(value)
    return value unless @digitsBeforeDecimal? or @digitsAfterDecimal?
    [before, after] = value.split('.')
    if @digitsBeforeDecimal?
      before = repeatString('0', @digitsBeforeDecimal - before.length) + before

    if after and @digitsAfterDecimal?
      after += repeatString('0', @digitsAfterDecimal - after.length)

    value = before
    value += ".#{after}" if after
    return value

  rangeToDatabase: (range) ->
    return null unless Array.isArray(range) and range.length is 2
    return @_valueToDatabase(range[0]) + @separator + @_valueToDatabase(range[1])


# Make lookup
attributeMetaConstructorMap = {
  range: RangeAttributeMeta
}

AttributeMeta.fromSpec = (attributeMetaSpec) ->
  if attributeMetaSpec.size # Back compat.
    attributeMetaSpec.rangeSize = attributeMetaSpec.size

  throw new Error("unrecognizable attributeMeta") unless typeof attributeMetaSpec is 'object'
  throw new Error("type must be defined") unless attributeMetaSpec.hasOwnProperty('type')
  throw new Error("type must be a string") unless typeof attributeMetaSpec.type is 'string'
  FilterConstructor = attributeMetaConstructorMap[attributeMetaSpec.type]
  throw new Error("unsupported attributeMeta type '#{attributeMetaSpec.type}'") unless FilterConstructor
  return new FilterConstructor(attributeMetaSpec)


# Export!
exports.AttributeMeta = AttributeMeta
exports.RangeAttributeMeta = RangeAttributeMeta
