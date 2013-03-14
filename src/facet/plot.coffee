# A function that takes a facet and
# Arguments* -> Segment -> void

facet.plot = {
  rect: ({left, width, right, top, height, bottom, stroke, fill, opacity}) ->
    left = wrapLiteral(left)
    width = wrapLiteral(width)
    right = wrapLiteral(right)
    top = wrapLiteral(top)
    height = wrapLiteral(height)
    bottom = wrapLiteral(bottom)
    fill = wrapLiteral(fill)
    opacity = wrapLiteral(opacity)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

      [x, w] = boxPosition(segment, stage.width, left, width, right)
      [y, h] = boxPosition(segment, stage.height, top, height, bottom)

      stage.node.append('rect').datum(segment)
        .attr('x', x)
        .attr('y', y)
        .attr('width', w)
        .attr('height', h)
        .style('fill', fill)
        .style('stroke', stroke)
        .style('opacity', opacity)
      return

  text: ({color, text, size, anchor, baseline, angle}) ->
    color = wrapLiteral(color)
    text = wrapLiteral(text)
    size = wrapLiteral(size)
    anchor = wrapLiteral(anchor)
    baseline = wrapLiteral(baseline)
    angle = wrapLiteral(angle)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Must have a point stage (is #{stage.type})") unless stage.type is 'point'
      myNode = stage.node.append('text').datum(segment)

      if angle
        myNode.attr('transform', "rotate(#{angle(segment)})")

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

  circle: ({radius, stroke, fill}) ->
    radius = wrapLiteral(radius)
    stroke = wrapLiteral(stroke)
    fill = wrapLiteral(fill)

    return (segment) ->
      stage = segment.getStage()
      throw new Error("Must have a point stage (is #{stage.type})") unless stage.type is 'point'
      stage.node.append('circle').datum(segment)
        .attr('r', radius)
        .style('fill', fill)
        .style('stroke', stroke)
      return
}
