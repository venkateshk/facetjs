segmentFilterFns = {
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

  within: ({prop, range}) ->
    throw new TypeError("range must be an array of two things") unless Array.isArray(range) and range.length is 2
    return (segment) -> range[0] <= getPropFromSegment(segment, prop) < range[1]

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
class FacetSegementFilter
  constructor: (@spec) ->

  valueOf: ->
    return @spec

  getFilterFn: ->
    return makeSegmentFilterFn(@spec)


exports.FacetSegementFilter = FacetSegementFilter
