createNode = (segment, space, nodeType, { title, link, visible, opacity, dash }) ->
  title = wrapLiteral(title)
  link = wrapLiteral(link)
  visible = wrapLiteral(visible)
  opacity = wrapLiteral(opacity)

  node = space.node

  if title or link
    node = node.append('a')
      .datum(segment)
      .attr('xlink:title', title)
      .attr('xlink:href', link)

  node = node.append(nodeType).datum(segment)
    .style('opacity', opacity)

  if visible
    node.style('display', if visible(segment) then null else 'none')

  if dash
    node.style('stroke-dasharray', dash)

  return node


# A function that takes a facet and
# Arguments* -> (Segment, Space) -> void

facet.plot = {
  box: (args = {}) ->
    {color, stroke, fill} = args
    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill or color)

    return (segment, space) ->
      throw new Error("Box must have a rectangle space (is #{space.type})") unless space.type is 'rectangle'

      createNode(segment, space, 'rect', args)
        .attr('x', Math.min(0, space.attr.width))
        .attr('y', Math.min(0, space.attr.height))
        .attr('width', Math.abs(space.attr.width))
        .attr('height', Math.abs(space.attr.height))
        .style('fill', fill)
        .style('stroke', stroke)
      return

  label: (args = {}) ->
    {color, text, size, anchor, baseline, angle} = args
    color = wrapLiteral(color)
    text = wrapLiteral(text ? 'Label')
    size = wrapLiteral(size)
    anchor = wrapLiteral(anchor)
    baseline = wrapLiteral(baseline)
    angle = wrapLiteral(angle)

    return (segment, space) ->
      throw new Error("Label must have a point space (is #{space.type})") unless space.type is 'point'

      myNode = createNode(segment, space, 'text', args)

      if angle
        myNode.attr('transform', "rotate(#{-angle(segment)})")

      if baseline
        myNode.attr('dy', (segment) ->
          baselineValue = baseline(segment)
          return if baselineValue is 'top' then '.71em' else if baselineValue is 'center' then '.35em' else null
        )

      myNode
        .style('font-size', size)
        .style('fill', color)
        .style('text-anchor', anchor)
        .text(text)
      return

  circle: (args = {}) ->
    {radius, area, color, stroke, fill} = args
    radius = wrapLiteral(radius)
    area = wrapLiteral(area)
    if area
      if radius
        throw new Error('Over-constrained by radius and area')
      else
        radius = (segment) -> Math.sqrt(area(segment) / Math.PI)
    else
      if not radius
        radius = -> 5

    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill or color)

    return (segment, space) ->
      throw new Error("Circle must have a point space (is #{space.type})") unless space.type is 'point'

      createNode(segment, space, 'circle', args)
        .attr('r', radius)
        .style('fill', fill)
        .style('stroke', stroke)

      return

  line: (args = {}) ->
    {stroke} = args
    return (segment, space) ->
      throw new Error("Line must have a line space (is #{space.type})") unless space.type is 'line'

      createNode(segment, space, 'line', args)
        .style('stroke', stroke)
        .attr('x1', -space.attr.length / 2)
        .attr('x2',  space.attr.length / 2)

      return
}
