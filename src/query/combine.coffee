
class FacetCombine
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
    combine = { method: @method }
    return combine



class SliceCombine extends FacetCombine
  constructor: ({@method, @sort, limit}) ->
    @_ensureMethod('slice')
    @limit = limit if limit?

  toString: ->
    return "SliceCombine"

  valueOf: ->
    combine = super.valueOf()
    combine.sort = @sort
    combine.limit = @limit if @limit
    return combine



class MatrixCombine extends FacetCombine
  constructor: ({@method, @sort, @limits}) ->
    @_ensureMethod('matrix')
    throw new TypeError("limits must be an array") unless Array.isArray(@limits)

  toString: ->
    return "MatrixCombine"

  valueOf: ->
    combine = super.valueOf()
    combine.sort = @sort
    combine.limits = @limits
    return combine



# Make lookup
combineConstructorMap = {
  "slice": SliceCombine
  "matrix": MatrixCombine
}


FacetCombine.fromSpec = (combineSpec) ->
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

