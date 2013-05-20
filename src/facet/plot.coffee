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
  box: (args) ->
    {color, stroke, fill} = args
    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill or color)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Box must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

      if stage.width > 0
        x = 0
        w = stage.width
      else
        x = stage.width
        w = -stage.width

      if stage.height > 0
        y = 0
        h = stage.height
      else
        y = stage.height
        h = -stage.height

      createNode(segment, 'rect', args)
        .attr('x', x)
        .attr('y', y)
        .attr('width', w)
        .attr('height', h)
        .style('fill', fill)
        .style('stroke', stroke)
      return

  label: (args) ->
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

  circle: (args) ->
    {radius, area, color, stroke, fill} = args
    radius = wrapLiteral(radius)
    area = wrapLiteral(area)
    if area
      if radius
        throw new Error('Over-constrained by radius and area')
      else
        radius = (segment) -> Math.qurt(area(segment) / Math.PI)

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

  line: (args) ->
    {color} = args
    return (segment) ->
      stage = segment.getStage()
      throw new Error("Circle must have a line stage (is #{stage.type})") unless stage.type is 'line'

      createNode(segment, 'line', args)
        .style('stroke', color)
        .attr('x1', -stage.length / 2)
        .attr('x2',  stage.length / 2)

      return
}
