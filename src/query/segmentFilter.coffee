{specialJoin, getValueOf, isTimezone, find, dummyObject} = require('./common')

getPropFromSegment = (segment, propName) ->
  return null unless segment
  segmentProp = segment.prop
  return null unless segmentProp
  return if segmentProp.hasOwnProperty(propName) then segmentProp[propName] else getPropFromSegment(segment.parent, propName)


class FacetSegmentFilter
  constructor: ->
    @type = 'base'

  _ensureType: (filterType) ->
    if not @type
      @type = filterType # Set the type if it is so far undefined
      return
    if @type isnt filterType
      throw new TypeError("incorrect segment filter type '#{@type}' (needs to be: '#{filterType}')")
    return

  _validateProp: ->
    if typeof @prop isnt 'string'
      throw new TypeError("prop must be a string")

  valueOf: ->
    return { type: @type }

  isEqual: (other) ->
    return Boolean(other) and @type is other.type and @prop is other.prop



class TrueSegmentFilter extends FacetSegmentFilter
  constructor: ({@type} = {}) ->
    @_ensureType('true')

  toString: ->
    return "Every segment"

  getFilterFn: ->
    return -> true



class FalseSegmentFilter extends FacetSegmentFilter
  constructor: ({@type} = {}) ->
    @_ensureType('false')

  toString: ->
    return "No segment"

  getFilterFn: ->
    return -> false


class IsSegmentFilter extends FacetSegmentFilter
  constructor: ({@type, @prop, @value}) ->
    @_ensureType('is')
    @_validateProp()

  toString: ->
    return "seg##{@prop} is #{@value}"

  valueOf: ->
    return { type: @type, prop: @prop, value: @value }

  isEqual: (other) ->
    return super(other) and other.value is @value

  getFilterFn: ->
    if Array.isArray(@value)
      # value can also be a range for direct interval comparisons
      myProp = @prop
      [start, end] = @value
      start = Date.parse(start) if typeof start is 'string'
      end = Date.parse(end) if typeof end is 'string'
      return (segment) ->
        [segStart, segEnd] = getPropFromSegment(segment, myProp)
        return segStart.valueOf() is start and segEnd.valueOf() is end
    else
      myProp = @prop
      myValue = @value
      return (segment) -> getPropFromSegment(segment, myProp) is myValue


class InSegmentFilter extends FacetSegmentFilter
  constructor: ({@type, @prop, @values}) ->
    @_ensureType('in')
    @_validateProp()
    throw new TypeError('values must be an array') unless Array.isArray(@values)

  toString: ->
    switch @values.length
      when 0 then return "No segment"
      when 1 then return "seg##{@prop} is #{@values[0]}"
      when 2 then return "seg##{@prop} is either #{@values[0]} or #{@values[1]}"
      else return "seg##{@prop} is one of: #{specialJoin(@values, ', ', ', or ')}"

  valueOf: ->
    return { type: @type, prop: @prop, values: @values }

  isEqual: (other) ->
    return super(other) and other.values.join(';') is @values.join(';')

  getFilterFn: ->
    myProp = @prop
    myValues = @values
    return (segment) -> getPropFromSegment(segment, myProp) in myValues



class NotSegmentFilter extends FacetSegmentFilter
  constructor: (arg) ->
    if arg not instanceof FacetFilter
      {@type, @filter} = arg
      @filter = FacetSegmentFilter.fromSpec(@filter)
    else
      @filter = arg
    @_ensureType('not')

  toString: ->
    return "not (#{@filter})"

  valueOf: ->
    return { type: @type, filter: @filter.valueOf() }

  isEqual: (other) ->
    return super(other) and @filter.isEqual(other.filter)

  getFilterFn: ->
    filterFn = @filter.getFilterFn()
    return (segment) -> not filterFn(segment)



class AndSegmentFilter extends FacetSegmentFilter
  constructor: (arg) ->
    if not Array.isArray(arg)
      {@type, @filters} = arg
      throw new TypeError('filters must be an array') unless Array.isArray(@filters)
      @filters = @filters.map(FacetSegmentFilter.fromSpec)
    else
      @filters = arg

    @_ensureType('and')

  toString: ->
    if @filters.length > 1
      return "(#{@filters.join(') and (')})"
    else
      return String(@filters[0])

  valueOf: ->
    return { type: @type, filters: @filters.map(getValueOf) }

  isEqual: (other) ->
    otherFilters = other.filters
    return super(other) and
           @filters.length is otherFilters.length and
           @filters.every((filter, i) -> filter.isEqual(otherFilters[i]))

  getFilterFn: ->
    filterFns = @filters.map((filter) -> filter.getFilterFn())
    return (segment) ->
      for filterFn in filterFns
        return false unless filterFn(segment)
      return true



class OrSegmentFilter extends FacetSegmentFilter
  constructor: (arg) ->
    if not Array.isArray(arg)
      {@type, @filters} = arg
      throw new TypeError('filters must be an array') unless Array.isArray(@filters)
      @filters = @filters.map(FacetSegmentFilter.fromSpec)
    else
      @filters = arg

    @_ensureType('or')

  toString: ->
    if @filters.length > 1
      return "(#{@filters.join(') or (')})"
    else
      return String(@filters[0])

  valueOf: ->
    return { type: @type, filters: @filters.map(getValueOf) }

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    otherFilters = other.filters
    return super(other) and
           @filters.length is otherFilters.length and
           @filters.every((filter, i) -> filter.isEqual(otherFilters[i]))

  getFilterFn: ->
    filterFns = @filters.map((filter) -> filter.getFilterFn())
    return (segment) ->
      for filterFn in filterFns
        return true if filterFn(segment)
      return false



# Make lookup
segmentFilterConstructorMap = {
  "true": TrueSegmentFilter
  "false": FalseSegmentFilter
  "is": IsSegmentFilter
  "in": InSegmentFilter
  "not": NotSegmentFilter
  "and": AndSegmentFilter
  "or": OrSegmentFilter
}

FacetSegmentFilter.fromSpec = (segmentFilterSpec) ->
  throw new Error("unrecognizable segment filter") unless typeof segmentFilterSpec is 'object'
  throw new Error("type must be defined") unless segmentFilterSpec.hasOwnProperty('type')
  throw new Error("type must be a string") unless typeof segmentFilterSpec.type is 'string'
  SegmentFilterConstructor = segmentFilterConstructorMap[segmentFilterSpec.type]
  throw new Error("unsupported segment filter type '#{segmentFilterSpec.type}'") unless SegmentFilterConstructor
  return new SegmentFilterConstructor(segmentFilterSpec)


# Export!
exports.FacetSegmentFilter = FacetSegmentFilter
exports.TrueSegmentFilter = TrueSegmentFilter
exports.FalseSegmentFilter = FalseSegmentFilter
exports.IsSegmentFilter = IsSegmentFilter
exports.InSegmentFilter = InSegmentFilter
exports.NotSegmentFilter = NotSegmentFilter
exports.AndSegmentFilter = AndSegmentFilter
exports.OrSegmentFilter = OrSegmentFilter

