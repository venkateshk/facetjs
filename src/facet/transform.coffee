# A function that transforms the stage from one form to another.
# Arguments* -> Segment -> PsudoStage

pointOnPoint = (left, right) ->
  left = wrapLiteral(left)
  right = wrapLiteral(right)

  if left
    if right
      throw new Error("Over-constrained")
    else
      return left
  else
    if right
      return (segment) -> -right(segment)
    else
      return () -> 0


pointOnLine = (left, right) ->
  left = wrapLiteral(left)
  right = wrapLiteral(right)

  if left
    if right
      throw new Error("Over-constrained")
    else
      return (segment, stageWidth) -> left(segment)
  else
    if right
      return (segment, stageWidth) -> stageWidth - right(segment)
    else
      return (segment, stageWidth) -> stageWidth / 2


lineOnLine = (left, width, right, dimName) ->
  left = wrapLiteral(left)
  width = wrapLiteral(width)
  right = wrapLiteral(right)

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
          throw new Error("Over-constrained by #{dimName}")
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


lineOnPoint = (left, width, right, dimName) ->
  left = wrapLiteral(left)
  width = wrapLiteral(width)
  right = wrapLiteral(right)

  if left and right
    throw new Error("Over-constrained") if width
    return (segment, stageWidth) ->
      leftValue = left(segment)
      rightValue = right(segment)
      if leftValue instanceof Interval or rightValue instanceof Interval
        throw new Error("Over-constrained by interval")
      return [-leftValue, leftValue + rightValue]

  flip = false
  if left and not right
    # Exploit the symmetry between left and right
    right = left
    flip = true

  fn = if width
    if right
      (segment) ->
        rightValue = right(segment)
        if rightValue instanceof Interval
          throw new Error("Over-constrained by #{dimName}")
        else
          widthValue = width(segment).valueOf()
          return [rightValue, widthValue]
    else
      (segment) ->
        widthValue = width(segment).valueOf()
        return [-widthValue / 2, widthValue]
  else
    if right
      (segment) ->
        rightValue = right(segment)
        if rightValue instanceof Interval
          return [rightValue.start, rightValue.end - rightValue.start]
        else
          return [0, rightValue]
    else
      throw new Error("Under-constrained")

  if flip
    return (segment) ->
      pos = fn(segment)
      pos[0] = -pos[0] - pos[1]
      return pos
  else
    return fn



checkStage = (stage, requiredType) ->
  if stage.type isnt requiredType
    throw new Error("Must have a #{requiredType} stage (is #{stage.type})")
  return


facet.transform = {
  point: {
    point: ({left, right, top, bottom} = {}) ->
      fx = pointOnPoint(left, right)
      fy = pointOnPoint(top, bottom)

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        return {
          type: 'point'
          x: fx(segment, stage.width)
          y: fy(segment, stage.height)
        }

    line: ({left, width, right} = {}) ->
      fx = lineOnPoint(left, width, right, 'width')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        [x, w] = fx(segment, stage.width)

        return {
          type: 'line'
          x
          width: w
        }

    rectangle: ({left, width, right, top, height, bottom} = {}) ->
      fx = lineOnPoint(left, width, right, 'width')
      fy = lineOnPoint(top, height, bottom, 'height')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        [x, w] = fx(segment, stage.width)
        [y, h] = fy(segment, stage.height)

        return {
          type: 'rectangle'
          x
          y
          width: w
          height: h
        }
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
      fx = pointOnLine(left, right)
      fy = pointOnLine(top, bottom)

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'rectangle')

        return {
          type: 'point'
          x: fx(segment, stage.width)
          y: fy(segment, stage.height)
        }

    line: ->
      throw "not implemented yet"

    rectangle: ({left, width, right, top, height, bottom} = {}) ->
      fx = lineOnLine(left, width, right, 'width')
      fy = lineOnLine(top, height, bottom, 'height')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'rectangle')

        [x, w] = fx(segment, stage.width)
        [y, h] = fy(segment, stage.height)

        return {
          type: 'rectangle'
          x
          y
          width: w
          height: h
        }
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
