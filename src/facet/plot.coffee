createNode = (segment, nodeType, { title, link, visible, opacity }) ->
  title = wrapLiteral(title)
  link = wrapLiteral(link)
  visible = wrapLiteral(visible)
  opacity = wrapLiteral(opacity)

  node = segment.getStage().node

  if title or link
    node = node.append('a')
      .datum(segment)
      .attr('xlink:title', title)
      .attr('xlink:link', link)

  node = node.append(nodeType).datum(segment)
    .style('opacity', opacity)

  if visible
    node.style('display', if visible(segment) then null else 'none')

  return node


# A function that takes a facet and
# Arguments* -> Segment -> void

facet.plot = {
  box: (args = {}) ->
    {color, stroke, fill} = args
    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill or color)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Box must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

      createNode(segment, 'rect', args)
        .attr('x', Math.min(0, stage.width))
        .attr('y', Math.min(0, stage.height))
        .attr('width', Math.abs(stage.width))
        .attr('height', Math.abs(stage.height))
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

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Label must have a point stage (is #{stage.type})") unless stage.type is 'point'

      myNode = createNode(segment, 'text', args)

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

    if not radius
      radius = -> 5

    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill or color)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Circle must have a point stage (is #{stage.type})") unless stage.type is 'point'

      createNode(segment, 'circle', args)
        .attr('r', radius)
        .style('fill', fill)
        .style('stroke', stroke)

      return

  line: (args = {}) ->
    {stroke} = args
    return (segment) ->
      stage = segment.getStage()
      throw new Error("Line must have a line stage (is #{stage.type})") unless stage.type is 'line'

      createNode(segment, 'line', args)
        .style('stroke', stroke)
        .attr('x1', -stage.length / 2)
        .attr('x2',  stage.length / 2)

      return
}
