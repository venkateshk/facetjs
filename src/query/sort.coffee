{specialJoin, getValueOf, find, dummyObject} = require('./common')

directionFns = {
  ascending: (a, b) ->
    a = a[0] if Array.isArray(a)
    b = b[0] if Array.isArray(b)
    return if a < b then -1 else if a > b then 1 else if a >= b then 0 else NaN

  descending: (a, b) ->
    a = a[0] if Array.isArray(a)
    b = b[0] if Array.isArray(b)
    return if b < a then -1 else if b > a then 1 else if b >= a then 0 else NaN
}

class FacetSort
  constructor: ({@compare, @prop, @direction}) ->
    @_verifyProp()
    @_verifyDirection()
    return

  _ensureCompare: (compare) ->
    if not @compare
      @compare = compare # Set the compare if it is so far undefined
      return
    if @compare isnt compare
      throw new TypeError("incorrect sort compare '#{@compare}' (needs to be: '#{compare}')")
    return

  _verifyProp: ->
    throw new TypeError("sort prop must be a string") unless typeof @prop is 'string'

  _verifyDirection: ->
    throw new Error("direction must be 'descending' or 'ascending'") unless directionFns[@direction]

  toString: ->
    return "base sort"

  valueOf: ->
    return {
      compare: @compare
      prop: @prop
      direction: @direction
    }

  toJSON: -> @valueOf.apply(this, arguments)

  getDirectionFn: ->
    return directionFns[@direction]

  getCompareFn: ->
    throw new Error('can not call this directly')

  getSegmentCompareFn: ->
    compareFn = @getCompareFn()
    return (a, b) -> compareFn(a.prop, b.prop)

  isEqual: (other) ->
    return Boolean(other) and
           @compare is other.compare and
           @prop is other.prop and
           @direction is other.direction



class NaturalSort extends FacetSort
  constructor: ->
    super
    @_ensureCompare('natural')

  toString: ->
    return "#{@compare}(#{@prop}, #{@direction})"

  getCompareFn: ->
    directionFn = @getDirectionFn()
    prop = @prop
    return (a, b) -> directionFn(a[prop], b[prop])



class CaseInsensetiveSort extends FacetSort
  constructor: ->
    super
    @_ensureCompare('caseInsensetive')

  toString: ->
    return "#{@compare}(#{@prop}, #{@direction})"

  getCompareFn: ->
    directionFn = @getDirectionFn()
    prop = @prop
    return (a, b) -> directionFn(a[prop].toLowerCase(), b[prop].toLowerCase())


# Make lookup
sortConstructorMap = {
  "natural": NaturalSort
  "caseInsensetive": CaseInsensetiveSort
}


FacetSort.fromSpec = (sortSpec) ->
  return sortSpec if sortSpec instanceof FacetSort
  throw new Error("unrecognizable sort") unless typeof sortSpec is 'object'
  throw new Error("compare must be defined") unless sortSpec.hasOwnProperty('compare')
  throw new Error("compare must be a string") unless typeof sortSpec.compare is 'string'
  SortConstructor = sortConstructorMap[sortSpec.compare]
  throw new Error("unsupported compare '#{sortSpec.compare}'") unless SortConstructor
  return new SortConstructor(sortSpec)


# Export!
exports.FacetSort = FacetSort
exports.NaturalSort = NaturalSort
exports.CaseInsensetiveSort = CaseInsensetiveSort

