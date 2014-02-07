{specialJoin, getValueOf, isTimezone, find, dummyObject} = require('./common')
{FacetOptions} = require('./options')
{FacetSegmentFilter} = require('./segmentFilter')
{FacetFilter, IsFilter, WithinFilter} = require('./filter')

class FacetSplit
  constructor: ({@bucket, @dataset}, dummy) ->
    throw new TypeError("can not call `new FacetSplit` directly use FacetSplit.fromSpec instead") unless dummy is dummyObject

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
    split.dataset = @dataset if @dataset
    split.segmentFilter = @segmentFilter.valueOf() if @segmentFilter
    split.options = @options.valueOf() if @options
    return split

  toJSON: -> @valueOf.apply(this, arguments)

  getDataset: ->
    return @dataset or 'main'

  getDatasets: ->
    return [@dataset or 'main']

  getFilterFor: ->
    throw new Error("this method should never be called directly")

  getFilterByDatasetFor: (prop) ->
    filterByDataset = {}
    filterByDataset[@getDataset()] = @getFilterFor(prop)
    return filterByDataset

  isEqual: (other, compareSegmentFilter) ->
    return Boolean(other) and
      @bucket is other.bucket and
      @attribute is other.attribute and
      Boolean(@options) is Boolean(other.options) and
      (not @options or @options.isEqual(other.options)) and
      (not compareSegmentFilter or (Boolean(@segmentFilter) is Boolean(other.segmentFilter and @segmentFilter.isEqual(other.segmentFilter))))

  getAttributes: ->
    return [@attribute]


class IdentitySplit extends FacetSplit
  constructor: ({name, @attribute, segmentFilter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @segmentFilter = FacetSegmentFilter.fromSpec(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @_ensureBucket('identity')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(`#{@attribute}`)")

  valueOf: ->
    split = super
    split.attribute = @attribute
    return split

  getFilterFor: (prop) ->
    return new IsFilter({
      attribute: @attribute
      value: prop[@name]
    })


class ContinuousSplit extends FacetSplit
  constructor: ({name, @attribute, @size, @offset, lowerLimit, upperLimit, segmentFilter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @segmentFilter = FacetSegmentFilter.fromSpec(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @offset ?= 0
    @lowerLimit = lowerLimit if lowerLimit?
    @upperLimit = upperLimit if upperLimit?
    throw new TypeError("size must be a number") unless typeof @size is 'number'
    throw new Error("size must be positive (is: #{@size})") unless @size > 0
    throw new TypeError("offset must be a number") unless typeof @offset is 'number'
    @_ensureBucket('continuous')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(`#{@attribute}`, #{@size}, #{@offset})")

  valueOf: ->
    split = super
    split.attribute = @attribute
    split.size = @size
    split.offset = @offset
    split.lowerLimit = @lowerLimit if @lowerLimit?
    split.upperLimit = @upperLimit if @upperLimit?
    return split

  getFilterFor: (prop) ->
    return new WithinFilter({
      attribute: @attribute
      range: prop[@name]
    })

  isEqual: (other, compareSegmentFilter) ->
    return super and @size is other.size and @offset is other.offset



class TimePeriodSplit extends FacetSplit
  constructor: ({name, @attribute, @period, @timezone, segmentFilter, options}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    @segmentFilter = FacetSegmentFilter.fromSpec(segmentFilter) if segmentFilter
    @options = new FacetOptions(options) if options
    @timezone ?= 'Etc/UTC'
    throw new TypeError("period must be in ['PT1S', 'PT1M', 'PT1H', 'P1D', 'P1W']") unless @period in ['PT1S', 'PT1M', 'PT1H', 'P1D', 'P1W']
    throw new TypeError("invalid timezone '#{@timezone}'") unless isTimezone(@timezone)
    @_ensureBucket('timePeriod')
    @_verifyName()
    @_verifyAttribute()

  toString: ->
    return @_addName("#{@bucket}(`#{@attribute}`, #{@period}, #{@timezone})")

  valueOf: ->
    split = super
    split.attribute = @attribute
    split.period = @period
    split.timezone = @timezone
    return split

  getFilterFor: (prop) ->
    return new WithinFilter({
      attribute: @attribute
      range: prop[@name]
    })

  isEqual: (other, compareSegmentFilter) ->
    return super and @period is other.period and @timezone is other.timezone



class TupleSplit extends FacetSplit
  constructor: ({name, @splits, segmentFilter}) ->
    super(arguments[0], dummyObject)
    throw new Error("tuple split does not use a name") if name
    @segmentFilter = FacetSegmentFilter.fromSpec(segmentFilter) if segmentFilter
    throw new TypeError("splits must be a non-empty array") unless Array.isArray(@splits) and @splits.length
    @splits = @splits.map((splitSpec) ->
      throw new Error("tuple splits can not be nested") if splitSpec.bucket is 'tuple'
      throw new Error("a split within a tuple must have a name") unless splitSpec.hasOwnProperty('name')
      throw new Error("a split within a tuple should not have a segmentFilter") if splitSpec.hasOwnProperty('segmentFilter')
      return FacetSplit.fromSpec(splitSpec)
    )
    @_ensureBucket('tuple')

  toString: ->
    return @_addName("(#{@splits.join(' x ')})")

  valueOf: ->
    split = super
    split.splits = @splits.map(getValueOf)
    return split

  getFilterFor: (prop) ->
    return new AndFilter(@splits.map((split) -> split.getFilterFor(prop)))

  isEqual: (other, compareSegmentFilter) ->
    otherSplits = other.splits
    return super and @splits.length is otherSplits.length and @splits.every((split, i) -> split.isEqual(otherSplits[i], true))

  getAttributes: ->
    return @splits.map(({attribute}) -> attribute).sort()


class ParallelSplit extends FacetSplit
  constructor: ({name, @splits, segmentFilter}) ->
    super(arguments[0], dummyObject)
    @name = name if name
    throw new TypeError("splits must be a non-empty array") unless Array.isArray(@splits) and @splits.length
    @splits = @splits.map((splitSpec) ->
      throw new Error("parallel splits can not be nested") if splitSpec.bucket is 'parallel'
      throw new Error("a split within a parallel must not have a name") if splitSpec.hasOwnProperty('name')
      throw new Error("a split within a parallel should not have a segmentFilter") if splitSpec.hasOwnProperty('segmentFilter')
      return FacetSplit.fromSpec(splitSpec)
    )
    @_ensureBucket('parallel')

  toString: ->
    return @_addName("#{@splits.join(' | ')}")

  valueOf: ->
    split = super
    split.splits = @splits.map(getValueOf)
    return split

  getFilterFor: (prop) ->
    firstSplit = @splits[0]
    value = prop[@name]
    return switch firstSplit.bucket
      when 'identity'
        new IsFilter({
          attribute: firstSplit.attribute
          value
        })

      when 'continuous', 'timePeriod'
        new WithinFilter({
          attribute: firstSplit.attribute
          range: value
        })

      else
        throw new Error("unsupported sub split '#{firstSplit.bucket}'")

  getFilterByDatasetFor: (prop) ->
    filterByDataset = {}
    for split in @splits
      filterByDataset[split.getDataset()] = split.getFilterFor(prop)
    return filterByDataset

  isEqual: (other, compareSegmentFilter) ->
    otherSplits = other.splits
    return super and @splits.length is otherSplits.length and @splits.every((split, i) -> split.isEqual(otherSplits[i], true))

  getDataset: ->
    throw new Error('getDataset not defined for ParallelSplit, use getDatasets')

  getDatasets: ->
    return @splits.map((split) -> split.getDataset())

  getAttributes: ->
    attributes = []
    for split in @splits
      for attribute in split.getAttributes()
        attributes.push(attribute) unless attribute in attributes
    return attributes.sort()


# Make lookup
splitConstructorMap = {
  "identity": IdentitySplit
  "continuous": ContinuousSplit
  "timePeriod": TimePeriodSplit
  "tuple": TupleSplit
  "parallel": ParallelSplit
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
exports.TimePeriodSplit = TimePeriodSplit
exports.TupleSplit = TupleSplit
exports.ParallelSplit = ParallelSplit

