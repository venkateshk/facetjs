# A function that transforms the stage from one form to another.
# Arguments* -> Segment -> PsudoStage

boxPosition = (segment, stageWidth, left, width, right) ->
  if left and width and right
    throw new Error("Over-constrained")

  if left
    leftValue = left(segment)
    if leftValue instanceof Interval
      throw new Error("Over-constrained by width") if width
      return [leftValue.start, leftValue.end - leftValue.start]
    else
      if width
        widthValue = width(segment).valueOf()
        return [leftValue, widthValue]
      else
        return [leftValue, stageWidth - leftValue]
  else if right
    rightValue = right(segment)
    if rightValue instanceof Interval
      throw new Error("Over-constrained by width") if width
      return [stageWidth - rightValue.start, rightValue.end - rightValue.start]
    else
      if width
        widthValue = width(segment).valueOf()
        return [stageWidth - rightValue - widthValue, widthValue]
      else
        return [0, stageWidth - rightValue]
  else
    if width
      widthValue = width(segment).valueOf()
      return [(stageWidth - widthValue) / 2, widthValue]
    else
      return [0, stageWidth]


facet.transform = {
  point: {
    point: ->
      throw "not implemented yet"

    line: ({length}) ->
      throw "not implemented yet"

    rectangle: ->
      throw "not implemented yet"
  }

  line: {
    point: ->
      throw "not implemented yet"

    line: ->
      throw "not implemented yet"

    rectangle: ->
      throw "not implemented yet"
  }

  rectangle: {
    point: ({left, right, top, bottom} = {}) ->
      left = wrapLiteral(left)
      right = wrapLiteral(right)
      top = wrapLiteral(top)
      bottom = wrapLiteral(bottom)

      # Make sure we are not over-constrained
      if (left and right) or (top and bottom)
        throw new Error("Over-constrained")

      fx = if left then (w, s) -> left(s) else if right  then (w, s) -> w - right(s)  else (w, s) -> w / 2
      fy = if top  then (h, s) -> top(s)  else if bottom then (h, s) -> h - bottom(s) else (h, s) -> h / 2

      return (segment) ->
        stage = segment.getStage()
        throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

        return {
          type: 'point'
          x: fx(stage.width, segment)
          y: fy(stage.height, segment)
        }

    line: ->
      throw "not implemented yet"

    rectangle: ->
      throw "not implemented yet"
  }

  polygon: {
    point: ->
      throw "not implemented yet"

    polygon: ->
      throw "not implemented yet"
  }

  # margin: ({left, width, right, top, height, bottom}) -> (segment) ->
  #   stage = segment.getStage()
  #   throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

  #   [x, w] = boxPosition(segment, stage.width, left, width, right)
  #   [y, h] = boxPosition(segment, stage.height, top, height, bottom)

  # move

  # rotate
}
