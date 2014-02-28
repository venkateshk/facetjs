cleanProp = (prop) ->
  for key, value of prop
    if key[0] is '_'
      delete prop[key]
    else if Array.isArray(value) and typeof value[0] is 'string'
      value[0] = new Date(value[0])
      value[1] = new Date(value[1])
  return


class SegmentTree
  constructor: ({prop, splits}, @parent = null) ->
    if prop
      cleanProp(prop)
      @prop = prop
    else if splits
      throw new Error("can not have splits without prop")

    if splits
      @splits = splits.map(((spec) -> new SegmentTree(spec, this)), this)

  valueOf: ->
    spec = {}
    if @prop
      spec.prop = @prop

    if @splits
      spec.splits = @splits.map((split) -> split.valueOf())
    return spec

  toJSON: -> @valueOf.apply(this, arguments)

  selfClean: ->
    for own k, v of this
      delete this[k] if k[0] is '_'

    if @splits
      for split in @splits
        split.selfClean()

    return this

  setSplits: (splits) ->
    for split in splits
      split.parent = this
    return @splits = splits

  getProp: (propName) ->
    segmentProp = @prop
    return null unless segmentProp
    return segmentProp[propName] if segmentProp.hasOwnProperty(propName)
    return if @parent then @parent.getProp(propName) else null

  getDepth: ->
    depth = 0
    node = this
    depth++ while node = node.parent
    return depth

  isSubTree: (subTree) ->
    while subTree
      return true if @prop is subTree.prop
      subTree = subTree.parent
    return false

  computeTags: (baseFilter) ->
    return

  # Flattens the segment tree into an array
  #
  # @param {prepend,append,none} order - what to do with the root of the tree
  # @return {Array(SegmentTree)} the tree nodes in the order specified
  flatten: (order = 'prepend') ->
    throw new TypeError('order must be on of prepend, append, or none') unless order in ['prepend', 'append', 'none']
    @_flattenHelper(order, result = [])
    return result

  _flattenHelper: (order, result) ->
    result.push(this) if order is 'prepend' or not @splits

    if @splits
      for split in @splits
        split._flattenHelper(order, result)

    result.push(this) if order is 'append'
    return


module.exports = SegmentTree

