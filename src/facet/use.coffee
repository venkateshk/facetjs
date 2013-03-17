# Extracts the property and other things from a segment

wrapLiteral = (arg) ->
  return if typeof arg in ['undefined', 'function'] then arg else facet.use.literal(arg)

getProp = (segment, propName) ->
  if not segment
    throw new Error("No such prop '#{propName}'")
  return segment.prop[propName] ? getProp(segment.parent, propName)

getScale = (segment, scaleName) ->
  if not segment
    throw new Error("No such scale '#{scaleName}'")
  return segment.scale[scaleName] ? getScale(segment.parent, scaleName)

facet.use = {
  literal: (value) -> () ->
    return value

  prop: (propName) ->
    throw new Error("must specify prop name") unless propName
    throw new TypeError("prop name must be a string") unless typeof propName is 'string'
    return (segment) ->
      return getProp(segment, propName)

  scale: (scaleName, use) ->
    throw new Error("must specify scale name") unless scaleName
    throw new TypeError("scale name must be a string") unless typeof scaleName is 'string'
    return (segment) ->
      scale = getScale(segment, scaleName)
      throw new Error("'#{scaleName}' scale is untrained") if scale.train
      use or= scale.use
      return scale.fn(use(segment))

  stage: (attr, scale) ->
    throw new Error("must specify attr") unless typeof attr is 'string'
    throw new Error("attr can not be 'type'") if attr is 'type'
    scale ?= 1
    return (segment) ->
      return segment.getStage()[attr] * scale

  interval: (start, end) ->
    start = wrapLiteral(start)
    end = wrapLiteral(end)
    return (segment) -> new Interval(start(segment), end(segment))

  fn: (args..., fn) -> (segment) ->
    throw new TypeError("second argument must be a function") unless typeof fn is 'function'
    return fn.apply(this, args.map((arg) -> arg(segment)))
}
