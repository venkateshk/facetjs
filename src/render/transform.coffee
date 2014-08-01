{wrapLiteral} = require('./common')
Interval = require('./interval')
{isInstanceOf} = require('../util')

# A function that transforms the space from one form to another.
# Arguments* -> Segment -> PsudoSpace

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
      return -> 0


pointOnLine = (args, leftName, rightName) ->
  left = wrapLiteral(args[leftName])
  right = wrapLiteral(args[rightName])

  if left
    if right
      throw new Error("Over-constrained by #{leftName} and #{rightName}")
    else
      return (segment, spaceWidth) -> left(segment)
  else
    if right
      return (segment, spaceWidth) -> spaceWidth - right(segment)
    else
      return (segment, spaceWidth) -> spaceWidth / 2


lineOnLine = (args, leftName, widthName, rightName) ->
  left = wrapLiteral(args[leftName])
  width = wrapLiteral(args[widthName])
  right = wrapLiteral(args[rightName])

  if left and right
    throw new Error("Over-constrained by #{widthName}") if width
    return (segment, spaceWidth) ->
      leftValue = left(segment)
      rightValue = right(segment)
      if isInstanceOf(leftValue, Interval) or isInstanceOf(rightValue, Interval)
        throw new Error("Over-constrained by interval")
      return [leftValue, spaceWidth - leftValue - rightValue]

  flip = false
  if right and not left
    # Exploit the symmetry between left and right
    left = right
    leftName = rightName
    flip = true

  fn = if width
    if left
      (segment, spaceWidth) ->
        leftValue = left(segment)
        if isInstanceOf(leftValue, Interval)
          throw new Error("Over-constrained by #{widthName}")
        else
          widthValue = width(segment).valueOf()
          return [leftValue, widthValue]
    else
      (segment, spaceWidth) ->
        widthValue = width(segment).valueOf()
        return [(spaceWidth - widthValue) / 2, widthValue]
  else
    if left
      (segment, spaceWidth) ->
        leftValue = left(segment)
        if isInstanceOf(leftValue, Interval)
          return [leftValue.start, leftValue.end - leftValue.start]
        else
          return [leftValue, spaceWidth - leftValue]
    else
      (segment, spaceWidth) -> [0, spaceWidth]

  if flip
    return (segment, spaceWidth) ->
      pos = fn(segment, spaceWidth)
      pos[0] = spaceWidth - pos[0] - pos[1]
      return pos
  else
    return fn


lineOnPoint = (args, leftName, widthName, rightName) ->
  left = wrapLiteral(args[leftName])
  width = wrapLiteral(args[widthName])
  right = wrapLiteral(args[rightName])

  if left and right
    throw new Error("Over-constrained by #{widthName}") if width
    return (segment, spaceWidth) ->
      leftValue = left(segment)
      rightValue = right(segment)
      if isInstanceOf(leftValue, Interval) or isInstanceOf(rightValue, Interval)
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
        if isInstanceOf(rightValue, Interval)
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
        if isInstanceOf(rightValue, Interval)
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



checkSpace = (space, requiredType) ->
  if space.type isnt requiredType
    throw new Error("Must have a #{requiredType} space (is #{space.type})")
  return


module.exports = {
  point: {
    point: (args = {}) ->
      fx = pointOnPoint(args, 'left', 'right')
      fy = pointOnPoint(args, 'top', 'bottom')

      return (segment, space) ->
        checkSpace(space, 'point')

        return {
          type: 'point'
          x: fx(segment, space.attr.width)
          y: fy(segment, space.attr.height)
          attr: {}
        }

    line: (args = {}) ->
      fx = lineOnPoint(args, 'left', 'width', 'right')

      return (segment, space) ->
        checkSpace(space, 'point')

        [x, w] = fx(segment, space.attr.width)

        return {
          type: 'line'
          x
          y: 0
          attr: {
            length: w
          }
        }

    rectangle: (args = {}) ->
      fx = lineOnPoint(args, 'left', 'width', 'right')
      fy = lineOnPoint(args, 'top', 'height', 'bottom')

      return (segment, space) ->
        checkSpace(space, 'point')

        [x, w] = fx(segment, space.attr.width)
        [y, h] = fy(segment, space.attr.height)

        return {
          type: 'rectangle'
          x
          y
          attr: {
            width: w
            height: h
          }
        }
  }

  line: {
    point: ->
      throw new Error("not implemented yet")

    line: ->
      throw new Error("not implemented yet")

    rectangle: ->
      throw new Error("not implemented yet")
  }

  rectangle: {
    point: (args = {}) ->
      fx = pointOnLine(args, 'left', 'right')
      fy = pointOnLine(args, 'top', 'bottom')

      return (segment, space) ->
        checkSpace(space, 'rectangle')

        return {
          type: 'point'
          x: fx(segment, space.attr.width)
          y: fy(segment, space.attr.height)
          attr: {}
        }

    line: (args = {}) ->
      { direction } = args
      # ToDo: some checks
      if direction is 'vertical'
        fx = pointOnLine(args, 'left', 'right')
        fy = lineOnLine(args, 'top', 'height', 'bottom')
      else
        fx = lineOnLine(args, 'left', 'width', 'right')
        fy = pointOnLine(args, 'top', 'bottom')

      return (segment, space) ->
        checkSpace(space, 'rectangle')

        if direction is 'vertical'
          x = fx(segment, space.attr.width)
          [y, l] = fy(segment, space.attr.height)
          y += l / 2 # hack
          a = 90
        else
          [x, l] = fx(segment, space.attr.width)
          x += l / 2 # hack
          y = fy(segment, space.attr.height)

        return {
          type: 'line'
          x
          y
          a
          attr: {
            length: l
          }
        }


    rectangle: (args = {}) ->
      fx = lineOnLine(args, 'left', 'width', 'right')
      fy = lineOnLine(args, 'top', 'height', 'bottom')

      return (segment, space) ->
        checkSpace(space, 'rectangle')

        [x, w] = fx(segment, space.attr.width)
        [y, h] = fy(segment, space.attr.height)

        return {
          type: 'rectangle'
          x
          y
          attr: {
            width: w
            height: h
          }
        }
  }

  polygon: {
    point: ->
      throw new Error("not implemented yet")

    polygon: ->
      throw new Error("not implemented yet")
  }

  # move

  # rotate
}
