# A function that transforms the stage from one form to another.
# Arguments* -> Segment -> PsudoStage

pointOnPoint = (args, leftName, rightName) ->
  left = wrapLiteral(args[leftName])
  right = wrapLiteral(args[rightName])

  if left
    if right
      throw new Error("Over-constrained by #{leftName} and #{rightName}")
    else
      return left
  else
    if right
      return (segment) -> -right(segment)
    else
      return () -> 0


pointOnLine = (args, leftName, rightName) ->
  left = wrapLiteral(args[leftName])
  right = wrapLiteral(args[rightName])

  if left
    if right
      throw new Error("Over-constrained by #{leftName} and #{rightName}")
    else
      return (segment, stageWidth) -> left(segment)
  else
    if right
      return (segment, stageWidth) -> stageWidth - right(segment)
    else
      return (segment, stageWidth) -> stageWidth / 2


lineOnLine = (args, leftName, widthName, rightName) ->
  left = wrapLiteral(args[leftName])
  width = wrapLiteral(args[widthName])
  right = wrapLiteral(args[rightName])

  if left and right
    throw new Error("Over-constrained by #{widthName}") if width
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
    leftName = rightName
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


lineOnPoint = (args, leftName, widthName, rightName) ->
  left = wrapLiteral(args[leftName])
  width = wrapLiteral(args[widthName])
  right = wrapLiteral(args[rightName])

  if left and right
    throw new Error("Over-constrained by #{widthName}") if width
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
    rightName = leftName
    flip = true

  fn = if width
    if right
      (segment) ->
        rightValue = right(segment)
        if rightValue instanceof Interval
          throw new Error("Over-constrained by #{widthName}")
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
      throw new Error("Under-constrained, must have ether #{leftName}, #{widthName} or #{rightName}")

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
    point: (args = {}) ->
      fx = pointOnPoint(args, 'left', 'right')
      fy = pointOnPoint(args, 'top', 'bottom')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        return {
          x: fx(segment, stage.width)
          y: fy(segment, stage.height)
          stage: {
            type: 'point'
          }
        }

    line: (args = {}) ->
      fx = lineOnPoint(args, 'left', 'width', 'right')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        [x, w] = fx(segment, stage.width)

        return {
          x
          y: 0
          stage: {
            type: 'line'
            length: w
          }
        }

    rectangle: (args = {}) ->
      fx = lineOnPoint(args, 'left', 'width', 'right')
      fy = lineOnPoint(args, 'top', 'height', 'bottom')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'point')

        [x, w] = fx(segment, stage.width)
        [y, h] = fy(segment, stage.height)

        return {
          x
          y
          stage: {
            type: 'rectangle'
            width: w
            height: h
          }
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
    point: (args = {}) ->
      fx = pointOnLine(args, 'left', 'right')
      fy = pointOnLine(args, 'top', 'bottom')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'rectangle')

        return {
          x: fx(segment, stage.width)
          y: fy(segment, stage.height)
          stage: {
            type: 'point'
          }
        }

    line: ->
      throw "not implemented yet"

    rectangle: (args = {}) ->
      fx = lineOnLine(args, 'left', 'width', 'right')
      fy = lineOnLine(args, 'top', 'height', 'bottom')

      return (segment) ->
        stage = segment.getStage()
        checkStage(stage, 'rectangle')

        [x, w] = fx(segment, stage.width)
        [y, h] = fy(segment, stage.height)

        return {
          x
          y
          stage: {
            type: 'rectangle'
            width: w
            height: h
          }
        }
  }

  polygon: {
    point: ->
      throw "not implemented yet"

    polygon: ->
      throw "not implemented yet"
  }

  # move

  # rotate
}
