# A function that takes a facet and
# Arguments* -> Segment -> void

facet.plot = {
  box: ({stroke, fill, opacity}) ->
    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill)
    opacity = wrapLiteral(opacity)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Box must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

      stage.node.append('rect').datum(segment)
        .attr('width', stage.width)
        .attr('height', stage.height)
        .style('fill', fill)
        .style('stroke', stroke)
        .style('opacity', opacity)
      return

  label: ({color, text, size, anchor, baseline, angle}) ->
    color = wrapLiteral(color)
    text = wrapLiteral(text ? 'Label')
    size = wrapLiteral(size)
    anchor = wrapLiteral(anchor)
    baseline = wrapLiteral(baseline)
    angle = wrapLiteral(angle)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Label must have a point stage (is #{stage.type})") unless stage.type is 'point'
      myNode = stage.node.append('text').datum(segment)

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

  circle: ({radius, area, stroke, fill}) ->
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
    fill = wrapLiteral(fill)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Circle must have a point stage (is #{stage.type})") unless stage.type is 'point'
      stage.node.append('circle').datum(segment)
        .attr('r', radius)
        .style('fill', fill)
        .style('stroke', stroke)
      return
}
