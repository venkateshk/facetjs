window.data1 = do ->
  pick = (arr) -> arr[Math.floor(Math.random() * arr.length)]

  now = Date.now()
  w = 100
  return d3.range(400).map (i) ->
    return {
      id: i
      time: new Date(now + i * 13 * 1000)
      letter: 'ABC'[Math.floor(3 * i/400)]
      number: pick([1, 10, 3, 4])
      scoreA: i * Math.random() * Math.random()
      scoreB: 10 * Math.random()
      walk: w += Math.random() - 0.5 + 0.02
    }

# =============================================================

arraySubclass = if [].__proto__
    # Until ECMAScript supports array subclassing, prototype injection works well.
    (array, prototype) ->
      array.__proto__ = prototype
      return array
  else
    # And if your browser doesn't support __proto__, we'll use direct extension.
    (array, prototype) ->
      array[property] = prototype[property] for property in prototype
      return array


flatten = (ar) -> Array::concat.apply([], ar)

# =============================================================

window.facet = facet = {}

# =============================================================
# SPLIT
# A split is a function that takes a row and returns a string-able thing.

facet.split = {
  natural: (attribute) -> (d) -> d[attribute]

  bucket: (attribute, size, offset) -> (d) ->
    b = Math.floor((d[attribute] + offset) / size) * size
    return "#{b};#{b + size}"

  timeBucket: (attribute) -> (d) -> d.getHour()
}

# =============================================================
# APPLY
# An apply is a function that takes an array of rows and returns a number.

facet.apply = {
  count: -> (ds) -> ds.length

  sum: (attribute) -> (ds) -> d3.sum(ds, (d) -> d[attribute])

  average: (attribute) -> (ds) -> d3.sum(ds, (d) -> d[attribute]) / ds.length

  min: (attribute) -> (ds) -> d3.min(ds, (d) -> d[attribute])

  max: (attribute) -> (ds) -> d3.max(ds, (d) -> d[attribute])

  unique: (attribute) -> (ds) ->
    seen = {}
    count = 0
    for d in ds
      v = d[attribute]
      if not seen[v]
        count++
        seen[v] = 1
    return count
}

# =============================================================
# PROP
# Extracts the property from a segment

facet.prop = (propName) -> (segment) ->
  return segment.prop[propName]

# =============================================================
# LAYOUT
# A function that takes a rectangle and a lists of facets and initializes their node. (Should be generalized to any shape).

divideLength = (length, sizes) ->
  totalSize = 0
  totalSize += size for size in sizes
  lengthPerSize = length / totalSize
  return sizes.map((size) -> size * lengthPerSize)

stripeTile = (dim1, dim2) ->
  makeTransform = (dim, value) ->
    return if dim is 'width' then "translate(#{value},0)" else "translate(0,#{value})"

  return ({ gap, size } = {}) -> (parentSegment, segmentGroup) ->
    gap or= 0
    size or= -> 1
    n = segmentGroup.length
    parentSize = parentSegment.size
    parentDim1 = parentSize[dim1]
    parentDim2 = parentSize[dim2]
    maxGap = Math.max(0, (parentDim1 - n * 2) / (n - 1)) # Each segment takes up at least 2px
    gap = Math.min(gap, maxGap)
    availableDim1 = parentDim1 - gap * (n - 1)
    dim1s = divideLength(availableDim1, segmentGroup.map(size))

    dimSoFar = 0
    for segment, i in segmentGroup
      curDim1 = dim1s[i]

      segmentSize = {}
      segmentSize[dim1] = curDim1
      segmentSize[dim2] = parentDim2

      segment.size = segmentSize

      segment.node
        .attr('transform', makeTransform(dim1, dimSoFar))
        .attr(dim1, curDim1)
        .attr(dim2, parentDim2)

      dimSoFar += curDim1 + gap

    return

facet.layout = {
  overlap: () -> {}

  horizontal: stripeTile('width', 'height')

  vertical: stripeTile('height', 'width')

  tile: ->
    return
}

# =============================================================
# PLOT
# A function that takes a facet and

facet.plot = {
  rect: ({ color }) -> ({ size, node, prop }) ->
    node.append('rect').datum({ size, prop })
      .attr('width', size.width)
      .attr('height', size.height)
      .style('fill', color)
      .style('stroke', 'black')
    return

  text: ({ color, text }) -> ({ size, node, prop }) ->
    node.append('text').datum({ size, prop })
      .attr('dy', '.71em')
      .style('fill', color)
      .text(text)
    return

  circle: ({ color }) -> ({ size, node, prop }) ->
    node.append('text').datum({ size, prop })
      .attr('dy', '.71em')
      .style('fill', color)
      .text(text)
    return
}

# =============================================================
# SORT

facet.sort = {
  natural: (attribute, direction = 'ASC') ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then d3.ascending else d3.descending
    return (a, b) -> cmpFn(a.prop[attribute], b.prop[attribute])

  caseInsensetive: ->
    direction = direction.toUpperCase()
    throw "direction has to be 'ASC' or 'DESC'" unless direction is 'ASC' or direction is 'DESC'
    cmpFn = if direction is 'ASC' then d3.ascending else d3.descending
    return (a, b) -> cmpFn(String(a.prop[attribute]).toLowerCase(), String(b.prop[attribute]).toLowerCase())
}


# =============================================================
# main

facetArrayPrototype = []

facetArrayPrototype.split = (name, split) ->
  throw new TypeError("Split must be a function") unless typeof split is 'function'

  segmentGroup = flatten(this).map (f) ->
    keys = []
    bucket = {}
    bucketValue = {}
    for d in f.data
      key = split(d)
      if not bucket[key]
        keys.push(key)
        bucket[key] = []
        bucketValue[key] = key # Key might not be a string
      bucket[key].push(d)

    return keys.map (key) ->
      prop = {}
      prop[name] = bucketValue[key]

      size = f.size

      node = f.node.append('g')
        .attr('width', size.width)
        .attr('height', size.height)

      return {
        parent: f
        data: bucket[key]
        size
        prop
        node
      }

  return makeFacetArray(segmentGroup)


facetArrayPrototype.layout = (layout) ->
  throw new TypeError("Layout must be a function") unless typeof layout is 'function'

  for segmentGroup in this
    layout(segmentGroup[0].parent, segmentGroup)

  return this


facetArrayPrototype.apply = (name, apply) ->
  throw new TypeError("Apply must be a function") unless typeof apply is 'function'

  for segmentGroup in this
    for segment in segmentGroup
      segment.prop[name] = apply(segment.data)

  return this


facetArrayPrototype.combine = ({ filter, sort, limit } = {}) ->
  if filter
    throw new TypeError("filter must be a function") unless typeof filter is 'function'
    #segmentGroup.sort(sort) for segmentGroup in this

  if sort
    throw new TypeError("sort must be a function") unless typeof sort is 'function'
    segmentGroup.sort(sort) for segmentGroup in this

  if limit?
    segmentGroup.splice(limit, segmentGroup.length - limit) for segmentGroup in this

  return this


facetArrayPrototype.plot = (plot) ->
  for segmentGroup in this
    for segment in segmentGroup
      plot(segment)

  return this


makeFacetArray = (arr) -> arraySubclass(arr, facetArrayPrototype)

facet.canvas = (selector, width, height, data) ->
  svg = d3.select(selector)
    .append('svg')
    .attr('width', width)
    .attr('height', height)

  return makeFacetArray([[{
    parent: null
    data: data
    node: svg
    size: { width, height }
    prop: {}
  }]])




