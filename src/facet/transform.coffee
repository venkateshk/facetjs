# A function that transforms the stage from one form to another.
# Arguments* -> Segment -> PsudoStage


boxPosition = (left, width, right, widthName) ->
  if left and right
    throw new Error("Over-constrained") if width
    return (segment, stageWidth) ->
      leftValue = left(segment)
      rightValue = right(segment)
      if leftValue instanceof Interval or rightValue instanceof Interval
        throw new Error("Over-constrained by interval")
      return [leftValue, stageWidth - leftValue - rightValue]

  flip = false
  if right and not left
    # Exploit the symmetry between left and right
    left = right
    flip = true

  fn = if width
    if left
      (segment, stageWidth) ->
        leftValue = left(segment)
        if leftValue instanceof Interval
          throw new Error("Over-constrained by #{widthName}")
        else
          widthValue = width(segment).valueOf()
          return [leftValue, widthValue]
    else
      (segment, stageWidth) ->
        widthValue = width(segment).valueOf()
        return [(stageWidth - widthValue) / 2, widthValue]
  else
    if left
      (segment, stageWidth) ->
        leftValue = left(segment)
        if leftValue instanceof Interval
          return [leftValue.start, leftValue.end - leftValue.start]
        else
          return [leftValue, stageWidth - leftValue]
    else
      (segment, stageWidth) -> [0, stageWidth]

  if flip
    return (segment, stageWidth) ->
      pos = fn(segment, stageWidth)
      pos[0] = stageWidth - pos[0] - pos[1]
      return pos
  else
    return fn


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

    rectangle: ({left, width, right, top, height, bottom}) ->
      left = wrapLiteral(left)
      width = wrapLiteral(width)
      right = wrapLiteral(right)
      top = wrapLiteral(top)
      height = wrapLiteral(height)
      bottom = wrapLiteral(bottom)

      fx = boxPosition(left, width, right, 'width')
      fy = boxPosition(top, height, bottom, 'height')

      return (segment) ->
        stage = segment.getStage()
        throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'

        [x, w] = fx(segment, stage.width)
        [y, h] = fy(segment, stage.height)

        return {
          type: 'rectangle'
          x
          y
          width: w
          height: h
        }
        return
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
