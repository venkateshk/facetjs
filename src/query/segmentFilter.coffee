getPropFromSegment = (segment, prop) ->
  return null unless segment and segment.prop
  return segment.prop[prop] or getPropFromSegment(segment.parent, prop)

segmentFilterFns = {
  true: ->
    return -> true

  false: ->
    return -> false

  is: ({prop, value}) ->
    if Array.isArray(value)
      # value can also be a range for direct interval comparisons
      [start, end] = value
      start = Date.parse(start) if typeof start is 'string'
      end = Date.parse(end) if typeof end is 'string'
      return (segment) ->
        [segStart, segEnd] = getPropFromSegment(segment, prop)
        return segStart.valueOf() is start and segEnd.valueOf() is end
    else
      return (segment) -> getPropFromSegment(segment, prop) is value

  in: ({prop, values}) ->
    return (segment) -> getPropFromSegment(segment, prop) in values

  not: ({filter}) ->
    throw new TypeError("filter must be a filter object") unless typeof filter is 'object'
    filter = makeBucketFilterFn(filter)
    return (segment) -> not filter(segment)

  and: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeBucketFilterFn)
    return (segment) ->
      for filter in filters
        return false unless filter(segment)
      return true

  or: ({filters}) ->
    throw new TypeError('must have some filters') unless filters.length
    filters = filters.map(makeBucketFilterFn)
    return (segment) ->
      for filter in filters
        return true if filter(segment)
      return false
}

makeSegmentFilterFn = (filter) ->
  throw new Error("type not defined in filter") unless filter.hasOwnProperty('type')
  throw new Error("invalid type in filter") unless typeof filter.type is 'string'
  segmentFilterFn = segmentFilterFns[filter.type]
  throw new Error("segment filter type '#{filter.type}' not defined") unless segmentFilterFn
  return segmentFilterFn(filter)


# ToDo: improve this
class FacetSegmentFilter
  constructor: (@spec) ->
    @type = 'base'

  _ensureType: (filterType) ->
    if not @type
      @type = filterType # Set the type if it is so far undefined
      return
    if @type isnt filterType
      throw new TypeError("incorrect filter type '#{@type}' (needs to be: '#{filterType}')")
    return

  _validateProp: ->
    if typeof @prop isnt 'string'
      throw new TypeError("prop must be a string")

  valueOf: ->
    return @spec

  getFilterFn: ->
    return makeSegmentFilterFn(@spec)


exports.FacetSegmentFilter = FacetSegmentFilter
