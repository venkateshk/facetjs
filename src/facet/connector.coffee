lineHasRun = false
areaHasRun = false

facet.connector = {
  line: ({color, width, opacity, interpolate, tension}) -> (segment) ->
    color = wrapLiteral(color)
    width = wrapLiteral(width or 1)
    opacity = wrapLiteral(opacity)
    interpolate = wrapLiteral(interpolate)
    tension = wrapLiteral(tension)

    colorValue = color(segment)
    widthValue = width(segment)
    opacityValue = opacity(segment)

    lineFn = d3.svg.line()
    lineFn.interpolate(interpolate(segment)) if interpolate
    lineFn.tension(tension(segment)) if tension

    stage = segment.getStage()
    { e:px, f:py } = stage.node.node().getScreenCTM()
    return (segments) ->
      return if lineHasRun
      lineHasRun = true

      points = segments.map((s) ->
        myStage = s.getStage()
        throw new Error("Line connector must have a point stage (is #{myStage.type})") unless myStage.type is 'point'
        matrix = myStage.node.node().getScreenCTM()
        return [matrix.e - px, matrix.f - py] # x, y
      )
      console.log points
      stage.node.append('path')
        .attr('d', lineFn(points))
        .style('stroke', colorValue)
        .style('opacity', opacityValue)
        .style('fill', 'none')
        .style('stroke-width', widthValue)

      return

  area: ({color, width, opacity, interpolate, tension}) -> (segment) ->
    color = wrapLiteral(color)
    width = wrapLiteral(width or 1)
    opacity = wrapLiteral(opacity)
    interpolate = wrapLiteral(interpolate)
    tension = wrapLiteral(tension)

    colorValue = color(segment)
    widthValue = width(segment)
    opacityValue = opacity(segment)

    areaFn = d3.svg.area()
    areaFn.interpolate(interpolate(segment)) if interpolate
    areaFn.tension(tension(segment)) if tension

    stage = segment.getStage()
    { e:px, f:py } = stage.node.node().getScreenCTM()
    return (segments) ->
      return if areaHasRun
      areaHasRun = true

      points = segments.map((s) ->
        myStage = s.getStage()
        throw new Error("Line connector must have a point stage (is #{myStage.type})") unless myStage.type is 'point'
        matrix = myStage.node.node().getScreenCTM()
        return [matrix.e - px, matrix.f - py] # x, y
      )
      console.log points
      stage.node.append('path')
        .attr('d', areaFn(points))
        .style('stroke', 'none')
        .style('opacity', opacityValue)
        .style('fill', colorValue)
        .style('stroke-width', widthValue)

      return
}
