{wrapLiteral} = require('./common')

# A function that takes a rectangle and a lists of facets and initializes their node. (Should be generalized to any shape).

divideLength = (length, sizes) ->
  totalSize = 0
  totalSize += size for size in sizes
  lengthPerSize = length / totalSize
  return sizes.map((size) -> size * lengthPerSize)

stripeTile = (dim1, dim2) -> ({ gap, size } = {}) ->
  gap or= 0
  size = wrapLiteral(size ? 1)

  return (segments, space) ->
    n = segments.length
    if space.type isnt 'rectangle'
      throw new Error("Must have a rectangular space (is #{space.type})")
    parentDim1 = space.attr[dim1]
    parentDim2 = space.attr[dim2]
    maxGap = Math.max(0, (parentDim1 - n * 2) / (n - 1)) # Each segment takes up at least 2px
    gap = Math.min(gap, maxGap)
    availableDim1 = parentDim1 - gap * (n - 1)
    dim1s = divideLength(availableDim1, segments.map(size))

    dimSoFar = 0
    return segments.map((segment, i) ->
      curDim1 = dim1s[i]

      pseudoSpace = {
        type: 'rectangle'
        x: 0
        y: 0
        attr: {}
      }
      pseudoSpace[if dim1 is 'width' then 'x' else 'y'] = dimSoFar
      pseudoSpace.attr[dim1] = curDim1
      pseudoSpace.attr[dim2] = parentDim2

      dimSoFar += curDim1 + gap
      return pseudoSpace
    )

module.exports = {
  overlap: ->
    return (segments, space) ->
      return segments.map((segment) ->
        return {
          type: space.type
          x: 0
          y: 0
          attr: space.attr
        }
      )

  horizontal: stripeTile('width', 'height')

  vertical: stripeTile('height', 'width')

  horizontalScale: (args) ->
    throw new Error("Must have args") unless args
    { scale, use, flip } = args
    throw new Error("Must have a scale") unless scale

    return (segments, space) ->
      throw new Error("Must have a rectangular space (is #{space.type})") if space.type isnt 'rectangle'

      spaceWidth = space.attr.width
      spaceHeight = space.attr.height

      scaleObj = segments[0].getScale(scale)
      use or= scaleObj.use

      return segments.map((segment, i) ->
        int = scaleObj.fn(use(segment))

        x = int.start
        width = int.end - int.start
        if flip
          x = spaceWidth - x - width

        return {
          type: 'rectangle'
          x
          y: 0
          attr: {
            width
            height: spaceHeight
          }
        }
      )

  tile: ->
    throw new Error("not implemented yet")
}
