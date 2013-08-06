
class FacetSplit
  constructor: ->
    return

  _ensureBucket: (bucket) ->
    if not @bucket
      @bucket = bucket # Set the bucket if it is so far undefined
      return
    if @bucket isnt bucket
      throw new TypeError("incorrect split bucket '#{@bucket}' (needs to be: '#{bucket}')")
    return

  _addName: (str) ->
    return str unless @name
    return "#{str} -> #{@name}"

  toString: ->
    return @_addName("base split")

  valueOf: ->
    split = { bucket: @bucket }
    split.name = @name if @name
    split.options = @options.valueOf() if @options
    return split


class IdentitySplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @_ensureBucket('identity')

  toString: ->
    return @_addName("#{@bucket}(#{@attribute})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    return split



class ContinuousSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @size, @offset, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @offset ?= 0
    throw new TypeError("size must be a number") unless typeof @size is 'number'
    throw new TypeError("offset must be a number") unless typeof @offset is 'number'
    @_ensureBucket('continuous')

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@size}, #{@offset})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.size = @size
    split.offset = @offset
    return split


class TimeDurationSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @duration, @offset, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @offset ?= 0
    throw new TypeError("duration must be a number") unless typeof @duration is 'number'
    throw new TypeError("offset must be a number") unless typeof @offset is 'number'
    @_ensureBucket('timeDuration')

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@duration}, #{@offset})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.duration = @duration
    split.offset = @offset
    return split


class TimePeriodSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @period, @timezone, options}) ->
    @name = name if name
    @options = new FacetOptions(options) if options
    @timezone ?= 'Etc/UTC'
    throw new TypeError("period must be in ['PT1S', 'PT1M', 'PT1H', 'P1D']") unless period in ['PT1S', 'PT1M', 'PT1H', 'P1D']
    throw new TypeError("timezone must be a string") unless typeof @timezone is 'string'
    @_ensureBucket('timePeriod')

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@duration}, #{@offset})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.period = @period
    split.timezone = @timezone
    return split


class TupleSplit extends FacetSplit
  constructor: ({name, @splits}) ->
    @name = name if name
    throw new TypeError("splits must be a non-empty array") unless Array.isArray(@splits) and @splits.length
    @splits = @splits.map(FacetSplit.fromSpec)
    @_ensureBucket('tuple')

  toString: ->
    return @_addName("(#{@splits.join(' x ')})")

  valueOf: ->
    split = super.valueOf()
    split.splits = @splits.map(getValueOf)
    return split


# Make lookup
splitConstructorMap = {
  "identity": IdentitySplit
  "continuous": ContinuousSplit
  "timeDuration": TimeDurationSplit
  "timePeriod": TimePeriodSplit
  "tuple": TupleSplit
}


FacetSplit.fromSpec = (splitSpec) ->
  SplitConstructor = splitConstructorMap[splitSpec.bucket]
  throw new Error("unsupported bucket #{splitSpec.bucket}") unless SplitConstructor
  return new SplitConstructor(splitSpec)


# Export!
exports.FacetSplit = FacetSplit
exports.IdentitySplit = IdentitySplit
exports.ContinuousSplit = ContinuousSplit
exports.TimeDurationSplit = TimeDurationSplit
exports.TimePeriodSplit = TimePeriodSplit
exports.TupleSplit = TupleSplit

