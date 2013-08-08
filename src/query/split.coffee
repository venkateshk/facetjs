
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

  _verifyName: ->
    return unless @name
    throw new TypeError("split name must be a string") unless typeof @name is 'string'

  _verifyAttribute: ->
    throw new TypeError("attribute must be a string") unless typeof @attribute is 'string'

  _addName: (str) ->
    return str unless @name
    return "#{str} -> #{@name}"

  toString: ->
    return @_addName("base split")

  valueOf: ->
    split = { bucket: @bucket }
    split.name = @name if @name
    split.segmentFilter = @segmentFilter.valueOf() if @segmentFilter
    split.options = @options.valueOf() if @options
    return split


class IdentitySplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, segmentFilter, options}) ->
    @name = name if name
    @segmentFilter = new FacetSegmentFilter(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @_ensureBucket('identity')
    @_verifyName()

  toString: ->
    return @_addName("#{@bucket}(#{@attribute})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    return split

  getFilterFor: (propValue) ->
    return new IsFilter({
      attribute: @attribute
      value: propValue
    })


class ContinuousSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @size, @offset, segmentFilter, options}) ->
    @name = name if name
    @segmentFilter = new FacetSegmentFilter(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @offset ?= 0
    throw new TypeError("size must be a number") unless typeof @size is 'number'
    throw new Error("size must be positive (is: #{@size})") unless @size > 0
    throw new TypeError("offset must be a number") unless typeof @offset is 'number'
    @_ensureBucket('continuous')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@size}, #{@offset})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.size = @size
    split.offset = @offset
    return split

  getFilterFor: (propValue) ->
    return new WithinFilter({
      attribute: @attribute
      range: propValue
    })


class TimeDurationSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @duration, @offset, segmentFilter, options}) ->
    @name = name if name
    @segmentFilter = new FacetSegmentFilter(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @offset ?= 0
    throw new TypeError("duration must be a number") unless typeof @duration is 'number'
    throw new TypeError("offset must be a number") unless typeof @offset is 'number'
    @_ensureBucket('timeDuration')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@duration}, #{@offset})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.duration = @duration
    split.offset = @offset
    return split

  getFilterFor: (propValue) ->
    return new WithinFilter({
      attribute: @attribute
      range: propValue
    })


class TimePeriodSplit extends FacetSplit
  constructor: ({name, @bucket, @attribute, @period, @timezone, segmentFilter, options}) ->
    @name = name if name
    @segmentFilter = new FacetSegmentFilter(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @timezone ?= 'Etc/UTC'
    throw new TypeError("period must be in ['PT1S', 'PT1M', 'PT1H', 'P1D']") unless @period in ['PT1S', 'PT1M', 'PT1H', 'P1D']
    throw new TypeError("timezone must be a string") unless typeof @timezone is 'string'
    @_ensureBucket('timePeriod')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(#{@attribute}, #{@period}, #{@timezone})")

  valueOf: ->
    split = super.valueOf()
    split.attribute = @attribute
    split.period = @period
    split.timezone = @timezone
    return split

  getFilterFor: (propValue) ->
    return new WithinFilter({
      attribute: @attribute
      range: propValue
    })


class TupleSplit extends FacetSplit
  constructor: ({name, @splits}) ->
    @name = name if name
    @segmentFilter = new FacetSegmentFilter(segmentFilter) if segmentFilter
    throw new TypeError("splits must be a non-empty array") unless Array.isArray(@splits) and @splits.length
    @splits = @splits.map((splitSpec) ->
      throw new Error("tuple splits can not be nested") if splitSpec.bucket is 'tuple'
      return FacetSplit.fromSpec(splitSpec)
    )
    @_ensureBucket('tuple')
    @_verifyName()

  toString: ->
    return @_addName("(#{@splits.join(' x ')})")

  valueOf: ->
    split = super.valueOf()
    split.splits = @splits.map(getValueOf)
    return split

  getFilterFor: (propValues...) ->
    throw new Error("bad number of values") if propValues.length isnt @splits.length
    return new AndFilter(@splits.map(split, i) -> split.getFilterFor(propValues[i]))


# Make lookup
splitConstructorMap = {
  "identity": IdentitySplit
  "continuous": ContinuousSplit
  "timeDuration": TimeDurationSplit
  "timePeriod": TimePeriodSplit
  "tuple": TupleSplit
}


FacetSplit.fromSpec = (splitSpec) ->
  throw new Error("unrecognizable split") unless typeof splitSpec is 'object'
  throw new Error("bucket must be defined") unless splitSpec.hasOwnProperty('bucket')
  throw new Error("bucket must be a string") unless typeof splitSpec.bucket is 'string'
  SplitConstructor = splitConstructorMap[splitSpec.bucket]
  throw new Error("unsupported bucket '#{splitSpec.bucket}'") unless SplitConstructor
  return new SplitConstructor(splitSpec)


# Export!
exports.FacetSplit = FacetSplit
exports.IdentitySplit = IdentitySplit
exports.ContinuousSplit = ContinuousSplit
exports.TimeDurationSplit = TimeDurationSplit
exports.TimePeriodSplit = TimePeriodSplit
exports.TupleSplit = TupleSplit

