# A function that takes a rectangle and a lists of facets and initializes their node. (Should be generalized to any shape).

divideLength = (length, sizes) ->
  totalSize = 0
  totalSize += size for size in sizes
  lengthPerSize = length / totalSize
  return sizes.map((size) -> size * lengthPerSize)

stripeTile = (dim1, dim2) -> ({ gap, size } = {}) ->
  gap or= 0
  size = wrapLiteral(size ? 1)

  return (parentSegment, segmentGroup) ->
    n = segmentGroup.length
    parentStage = parentSegment.getStage()
    if parentStage.type isnt 'rectangle'
      throw new Error("Must have a rectangular stage (is #{parentStage.type})")
    parentDim1 = parentStage[dim1]
    parentDim2 = parentStage[dim2]
    maxGap = Math.max(0, (parentDim1 - n * 2) / (n - 1)) # Each segment takes up at least 2px
    gap = Math.min(gap, maxGap)
    availableDim1 = parentDim1 - gap * (n - 1)
    dim1s = divideLength(availableDim1, segmentGroup.map(size))

    dimSoFar = 0
    return segmentGroup.map((segment, i) ->
      curDim1 = dim1s[i]

      psudoStage = {
        type: 'rectangle'
        x: 0
        y: 0
      }
      psudoStage[if dim1 is 'width' then 'x' else 'y'] = dimSoFar
      psudoStage[dim1] = curDim1
      psudoStage[dim2] = parentDim2

      dimSoFar += curDim1 + gap
      return psudoStage
    )

facet.layout = {
  overlap: () -> {}

  horizontal: stripeTile('width', 'height')

  vertical: stripeTile('height', 'width')

  horizontalScale: ({ scale, use, flip }) ->
    return (parentSegment, segmentGroup) ->
      parentStage = parentSegment.getStage()
      if parentStage.type isnt 'rectangle'
        throw new Error("Must have a rectangular stage (is #{parentStage.type})")
      parentWidth = parentStage.width
      parentHeight = parentStage.height

      scaleObj = getScale(segmentGroup[0], scale)
      use or= scaleObj.use

      return segmentGroup.map((segment, i) ->
        int = scaleObj.fn(use(segment))

        x = int.start
        width = int.end - int.start
        if flip
          x = parentWidth - x - width

        return {
          type: 'rectangle'
          x
          y: 0
          width
          height: parentHeight
        }
      )

  tile: ->
    throw "not implemented yet"
}
