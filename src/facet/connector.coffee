facet.connector = {
  line: ({color, width, opacity, interpolate, tension}) ->
    color = wrapLiteral(color)
    width = wrapLiteral(width or 1)
    opacity = wrapLiteral(opacity)
    interpolate = wrapLiteral(interpolate)
    tension = wrapLiteral(tension)
    lineHasRun = false

    return (segment) ->
      colorValue = color(segment)
      widthValue = width(segment)
      opacityValue = opacity(segment)

      lineFn = d3.svg.line()
      lineFn.interpolate(interpolate(segment)) if interpolate
      lineFn.tension(tension(segment)) if tension

      stage = segment.getStage()
      invParentMatrix = stage.node.node().getScreenCTM().inverse()
      return (segments) ->
        return if lineHasRun
        lineHasRun = true

        points = segments.map((s) ->
          myStage = s.getStage()
          throw new Error("Line connector must have a point stage (is #{myStage.type})") unless myStage.type is 'point'
          { e, f } = invParentMatrix.multiply(myStage.node.node().getScreenCTM())
          return [e, f] # x, y
        )

        stage.node.append('path')
          .attr('d', lineFn(points))
          .style('stroke', colorValue)
          .style('opacity', opacityValue)
          .style('fill', 'none')
          .style('stroke-width', widthValue)

        return

  area: ({color, width, opacity, interpolate, tension}) ->
    color = wrapLiteral(color)
    width = wrapLiteral(width or 1)
    opacity = wrapLiteral(opacity)
    interpolate = wrapLiteral(interpolate)
    tension = wrapLiteral(tension)
    areaHasRun = false

    return (segment) ->
      colorValue = color(segment)
      widthValue = width(segment)
      opacityValue = opacity(segment)

      areaFn = d3.svg.area()
        .x0((d) -> d[0])
        .y0((d) -> d[1])
        .x1((d) -> d[2])
        .y1((d) -> d[3])
      areaFn.interpolate(interpolate(segment)) if interpolate
      areaFn.tension(tension(segment)) if tension

      stage = segment.getStage()
      invParentMatrix = stage.node.node().getScreenCTM().inverse()
      return (segments) ->
        return if areaHasRun
        areaHasRun = true

        points = segments.map((s) ->
          myStage = s.getStage()
          throw new Error("Line connector must have a point stage (is #{myStage.type})") unless myStage.type is 'line'
          len = myStage.length / 2
          { a, b, e, f } = invParentMatrix.multiply(myStage.node.node().getScreenCTM())

          return [-a*len+e, -b*len+f, a*len+e, b*len+f] # x1, y1, x2, y2
        )

        stage.node.append('path')
          .attr('d', areaFn(points))
          .style('stroke', 'none')
          .style('opacity', opacityValue)
          .style('fill', colorValue)
          .style('stroke-width', widthValue)

        return
}
