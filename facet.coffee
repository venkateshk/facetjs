
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

class Segment
  constructor: ({ @parent, @data, @node, stage, @prop }) ->
    throw "invalid stage" unless typeof stage?.type is 'string'
    @_stageStack = [stage]

  getStage: ->
    return @_stageStack[@_stageStack.length - 1]

  setStage: (stage) ->
    throw "invalid stage" unless typeof stage?.type is 'string'
    @_stageStack[@_stageStack.length - 1] = stage
    return

  pushStage: (stage) ->
    throw "invalid stage" unless typeof stage?.type is 'string'
    @_stageStack.push(stage)
    return

  popStage: ->
    throw "must have at least one stage" if @_stageStack.length < 2
    @_stageStack.pop()
    return


window.facet = facet = {}

# =============================================================
# SPLIT
# A split is a function that takes a row and returns a string-able thing.

facet.split = {
  natural: (attribute) -> (d) -> d[attribute]

  bucket: (attribute, size, offset) -> (d) ->
    b = Math.floor((d[attribute] + offset) / size) * size
    return "#{b};#{b + size}"

  time: {
    second: (attribute) -> (d) ->
      ds = new Date(d[attribute])
      ds.setUTCMilliseconds(0)
      de = new Date(ds)
      de.setUTCMilliseconds(1000)
      return [ds, de]

    minute: (attribute) -> (d) ->
      ds = new Date(d[attribute])
      ds.setUTCSeconds(0, 0)
      de = new Date(ds)
      de.setUTCSeconds(60)
      return [ds, de]

    hour: (attribute) -> (d) ->
      ds = new Date(d[attribute])
      ds.setUTCMinutes(0, 0, 0)
      de = new Date(ds)
      de.setUTCMinutes(60)
      return [ds, de]

    day: (attribute) -> (d) ->
      ds = new Date(d[attribute])
      ds.setUTCHours(0, 0, 0, 0)
      de = new Date(ds)
      de.setUTCHours(24)
      return [ds, de]
  }
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
    for segment, i in segmentGroup
      curDim1 = dim1s[i]

      segmentStage = { type: 'rectangle' }
      segmentStage[dim1] = curDim1
      segmentStage[dim2] = parentDim2

      segment.setStage(segmentStage)

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
# TRANSFORM STAGE
# A function that transforms the stage from one form to another.
# Arguments* -> Segment -> void

facet.stage = {
  rectToPoint: (xPos, yPos) -> (segment) ->
    stage = segment.getStage()
    throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'
    segment.pushStage({
      type: 'point'
      x: xPos * stage.width
      y: yPos * stage.height
    })
    return
}

# =============================================================
# PLOT
# A function that takes a facet and
# Arguments* -> Segment -> void

facet.plot = {
  rect: ({ color }) -> (segment) ->
    stage = segment.getStage()
    throw new Error("Must have a rectangle stage (is #{stage.type})") unless stage.type is 'rectangle'
    segment.node.append('rect').datum(segment)
      .attr('width', stage.width)
      .attr('height', stage.height)
      .style('fill', color)
      .style('stroke', 'black')
    return

  text: ({ color, text }) -> (segment) ->
    stage = segment.getStage()
    throw new Error("Must have a point stage (is #{stage.type})") unless stage.type is 'point'
    segment.node.append('text').datum(segment)
      .attr('x', stage.x)
      .attr('y', stage.y)
      .attr('dy', '.71em')
      .style('fill', color)
      .text(text)
    return

  circle: ({ color }) -> (segment) ->
    stage = segment.getStage()
    throw new Error("Must have a point stage (is #{stage.type})") unless stage.type is 'point'
    segment.node.append('text').datum(segment)
      .attr('cx', stage.x)
      .attr('cy', stage.y)
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

facetArrayPrototype._eachSegment = (fn) ->
  for segmentGroup in this
    for segment in segmentGroup
      fn(segment)
  return

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
      stage = f.getStage()
      node = f.node.append('g')

      return new Segment({
        parent: f
        data: bucket[key]
        stage
        prop
        node
      })

  return makeFacetArray(segmentGroup)


facetArrayPrototype.layout = (layout) ->
  throw new TypeError("Layout must be a function") unless typeof layout is 'function'

  for segmentGroup in this
    parentSegment = segmentGroup[0].parent
    throw new Error("You must split before calling layout") unless parentSegment
    layout(parentSegment, segmentGroup)

  return this


facetArrayPrototype.apply = (name, apply) ->
  throw new TypeError("Apply must be a function") unless typeof apply is 'function'
  @_eachSegment (segment) -> segment.prop[name] = apply(segment.data)
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


facetArrayPrototype.stage = (transform) ->
  @_eachSegment transform
  return this


facetArrayPrototype.pop = ->
  @_eachSegment (segment) -> segment.popStage()
  return this


facetArrayPrototype.plot = (plot) ->
  @_eachSegment plot
  return this


facetArrayPrototype.render = ->
  return this



makeFacetArray = (arr) -> arraySubclass(arr, facetArrayPrototype)

facet.canvas = (selector, width, height, data) ->
  svg = d3.select(selector)
    .append('svg')
    .attr('width', width)
    .attr('height', height)

  return makeFacetArray([[new Segment({
    parent: null
    data: data
    node: svg
    stage: { type: 'rectangle', width, height }
    prop: {}
  })]])


# =============================================================
# =============================================================

facet.driver = {
  simple: (data) -> (query, callback) ->

    # keys = []
    # bucket = {}
    # bucketValue = {}
    # for d in f.data
    #   key = split(d)
    #   if not bucket[key]
    #     keys.push(key)
    #     bucket[key] = []
    #     bucketValue[key] = key # Key might not be a string
    #   bucket[key].push(d)
    return
}












