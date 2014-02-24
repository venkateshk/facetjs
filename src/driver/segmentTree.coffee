cleanProp = (prop) ->
  for key of prop
    delete prop[key] if key[0] is '_'
  return


class SegmentTree
  constructor: ({prop, splits}, @parent = null) ->
    if prop
      cleanProp(prop)
      @prop = prop

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


module.exports = SegmentTree

