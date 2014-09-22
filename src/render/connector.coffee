d3 = require('d3')
{ wrapLiteral } = require('./common')

# Arguments* -> (Segment, Space) -> ([Spaces]) -> void

module.exports = {
  line: ({color, width, opacity, interpolate, tension}) ->
    color = wrapLiteral(color)
    width = wrapLiteral(width or 1)
    opacity = wrapLiteral(opacity or 1)
    interpolate = wrapLiteral(interpolate)
    tension = wrapLiteral(tension)

    return (segment, space) ->
      colorValue = color(segment)
      widthValue = width(segment)
      opacityValue = opacity(segment)

      lineFn = d3.svg.line()
      lineFn.interpolate(interpolate(segment)) if interpolate
      lineFn.tension(tension(segment)) if tension

      invParentMatrix = space.node.node().getScreenCTM().inverse()
      return (spaces) ->
        points = spaces.map((space) ->
          throw new Error("Line connector must have a point space (is #{space.type})") unless space.type is 'point'
          { e, f } = invParentMatrix.multiply(space.node.node().getScreenCTM())
          return [e, f] # x, y
        )

        space.node.append('path')
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

    return (segment, space) ->
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

      invParentMatrix = space.node.node().getScreenCTM().inverse()
      return (spaces) ->
        points = spaces.map((space) ->
          throw new Error("Line connector must have a point space (is #{space.type})") unless space.type is 'line'
          len = space.length / 2
          { a, b, e, f } = invParentMatrix.multiply(space.node.node().getScreenCTM())

          return [
            -a * len + e # x1
            -b * len + f # y1
            +a * len + e # x2
            +b * len + f # y2
          ]
        )

        space.node.append('path')
          .attr('d', areaFn(points))
          .style('stroke', 'none')
          .style('opacity', opacityValue)
          .style('fill', colorValue)
          .style('stroke-width', widthValue)

        return
}
