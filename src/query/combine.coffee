{specialJoin, getValueOf, find, dummyObject} = require('./common')
{FacetSort} = require('./sort')

class FacetCombine
  operation: 'combine'

  constructor: ->
    return

  _ensureMethod: (method) ->
    if not @method
      @method = method # Set the method if it is so far undefined
      return
    if @method isnt method
      throw new TypeError("incorrect combine method '#{@method}' (needs to be: '#{method}')")
    return

  toString: ->
    return @_addName("base combine")

  valueOf: ->
    combine = { method: @method, sort: @sort.valueOf() }
    return combine

  toJSON: -> @valueOf.apply(this, arguments)

  isEqual: (other) ->
    return Boolean(other) and
           @method is other.method and
           @sort.isEqual(other.sort)



class SliceCombine extends FacetCombine
  constructor: ({@method, @sort, limit}) ->
    @sort = FacetSort.fromSpec(@sort)
    @_ensureMethod('slice')
    if limit?
      throw new TypeError('limit must be a number') if isNaN(limit)
      @limit = Number(limit)

  toString: ->
    return "SliceCombine"

  valueOf: ->
    combine = super
    combine.limit = @limit if @limit?
    return combine

  isEqual: (other) ->
    return super and @limit is other.limit



class MatrixCombine extends FacetCombine
  constructor: ({@method, @sort, @limits}) ->
    @sort = FacetSort.fromSpec(@sort)
    @_ensureMethod('matrix')
    throw new TypeError("limits must be an array") unless Array.isArray(@limits)

  toString: ->
    return "MatrixCombine"

  valueOf: ->
    combine = super
    combine.limits = @limits
    return combine

  isEqual: (other) ->
    return super and @limits.join(';') is other.limits.join(';')



# Make lookup
combineConstructorMap = {
  "slice": SliceCombine
  "matrix": MatrixCombine
}


FacetCombine.fromSpec = (combineSpec) ->
  return combineSpec if combineSpec instanceof FacetCombine
  throw new Error("unrecognizable combine") unless typeof combineSpec is 'object'
  combineSpec.method ?= combineSpec.combine # ToDo: remove this. combineSpec.combine is a backwards compat. hack, remove it.
  throw new Error("method not defined") unless combineSpec.hasOwnProperty('method')
  throw new Error("method must be a string") unless typeof combineSpec.method is 'string'
  CombineConstructor = combineConstructorMap[combineSpec.method]
  throw new Error("unsupported method #{combineSpec.method}") unless CombineConstructor
  return new CombineConstructor(combineSpec)


# Export!
exports.FacetCombine = FacetCombine
exports.SliceCombine = SliceCombine
exports.MatrixCombine = MatrixCombine

