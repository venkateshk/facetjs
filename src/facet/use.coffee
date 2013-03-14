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
  prop: (propName) -> (segment) ->
    return getProp(segment, propName)

  literal: (value) -> () ->
    return value

  fn: (args..., fn) -> (segment) ->
    throw new TypeError("second argument must be a function") unless typeof fn is 'function'
    return fn.apply(this, args.map((arg) -> arg(segment)))

  scale: (scaleName, use) -> (segment) ->
    scale = getScale(segment, scaleName)
    throw new Error("'#{scaleName}' scale is untrained") if scale.train
    use or= scale.use
    return scale.fn(use(segment))

  interval: (start, end) ->
    start = wrapLiteral(start)
    end = wrapLiteral(end)
    return (segment) -> new Interval(start(segment), end(segment))
}
