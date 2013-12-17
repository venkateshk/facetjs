# Extracts the property and other things from a segment
{useLiteral, wrapLiteral} = require('./common')
Interval = require('./interval')

module.exports = {
  literal: useLiteral

  prop: (propName) ->
    throw new Error("must specify prop name") unless propName
    throw new TypeError("prop name must be a string") unless typeof propName is 'string'
    return (segment) ->
      return segment.getProp(propName)

  comulative: (use) ->
    use = wrapLiteral(use)
    tally = 0
    curParent = null
    return (segment) ->
      v = use(segment)
      if curParent isnt segment.parent
        curParent = segment.parent
        tally = 0
      ret = tally
      tally += v
      return ret

  scale: (scaleName, use) ->
    use = wrapLiteral(use)
    throw new Error("must specify scale name") unless scaleName
    throw new TypeError("scale name must be a string") unless typeof scaleName is 'string'
    return (segment) ->
      scale = segment.getScale(scaleName)
      throw new Error("'#{scaleName}' scale is untrained") if scale.train
      use or= scale.use
      return scale.fn(use(segment))

  space: (attrName, scale) ->
    throw new Error("must specify attr") unless typeof attrName is 'string'
    scale ?= 1
    return (space) -> space.attr[attrName] * scale

  interval: (start, end) ->
    start = wrapLiteral(start)
    end = wrapLiteral(end)
    return (segment) -> new Interval(start(segment), end(segment))

  length: (interval) ->
    interval = wrapLiteral(interval)
    return (segment) ->
      i = interval(segment)
      throw new TypeError("must have an interval") unless i instanceof Interval
      return i.valueOf()

  fn: (args..., fn) -> (segment) ->
    throw new TypeError("second argument must be a function") unless typeof fn is 'function'
    return fn.apply(this, args.map((arg) -> arg(segment)))
}
