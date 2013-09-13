
class FacetSort
  constructor: ->
    return

  _ensureCompare: (compare) ->
    if not @compare
      @compare = compare # Set the compare if it is so far undefined
      return
    if @compare isnt compare
      throw new TypeError("incorrect sort compare '#{@compare}' (needs to be: '#{compare}')")
    return

  _verifyProp: ->
    throw new TypeError("sort name must be a string") unless typeof @prop is 'string'

  _verifyDirection: ->
    throw new Error("direction must be 'descending' or 'ascending'") unless @direction in ['descending', 'ascending']

  toString: ->
    return "base sort"

  valueOf: ->
    return { compare: @compare, prop: @prop, direction: @direction }

  toJSON: @::valueOf

  isEqual: (other) ->
    return Boolean(other) and
           @compare is other.compare and
           @prop is other.prop and
           @direction is other.direction



class NaturalSort extends FacetSort
  constructor: ({@compare, @prop, @direction}) ->
    @_ensureCompare('natural')
    @_verifyProp()
    @_verifyDirection()

  toString: ->
    return "#{@compare}(#{@prop}, #{@direction})"



class CaseInsensetiveSort extends FacetSort
  constructor: ({@compare, @prop, @direction}) ->
    @_ensureCompare('caseInsensetive')
    @_verifyProp()
    @_verifyDirection()

  toString: ->
    return "#{@compare}(#{@prop}, #{@direction})"



# Make lookup
sortConstructorMap = {
  "natural": NaturalSort
  "caseInsensetive": CaseInsensetiveSort
}


FacetSort.fromSpec = (sortSpec) ->
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

