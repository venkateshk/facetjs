
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
  constructor: ({ @parent, @node, stage, @prop, @splits }) ->
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
  natural: (attribute) -> {
      bucket: 'natural'
      attribute
    }

  even: (attribute, size, offset) -> {
      bucket: 'even'
      attribute
      size
      offset
    }

  time: (attribute, duration) ->
    throw new Error("Invalid duration '#{duration}'") unless duration in ['second', 'minute', 'hour', 'day']
    return {
      bucket: 'time'
      attribute
      duration
    }
}

# =============================================================
# APPLY
# An apply is a function that takes an array of rows and returns a number.

facet.apply = {
  count: -> {
    aggregate: 'count'
  }

  sum: (attribute) -> {
    aggregate: 'sum'
    attribute
  }

  average: (attribute) -> {
    aggregate: 'sum'
    attribute
  }

  min: (attribute) -> {
    aggregate: 'min'
    attribute
  }

  max: (attribute) -> {
    aggregate: 'max'
    attribute
  }

  unique: (attribute) -> {
    aggregate: 'unique'
    attribute
  }
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
  natural: (attribute, direction = 'ASC') -> {
    compare: 'natural'
    attribute
    direction
  }

  caseInsensetive: (attribute, direction = 'ASC') -> {
    compare: 'caseInsensetive'
    attribute
    direction
  }
}


# =============================================================
# main

class FacetJob
  constructor: (@driver) ->
    @ops = []

  split: (propName, split) ->
    split = _.clone(split)
    split.operation = 'split'
    split.prop = propName
    @ops.push(split)
    return this

  layout: (layout) ->
    throw new TypeError("Layout must be a function") unless typeof layout is 'function'
    @ops.push({
      operation: 'layout'
      layout
    })
    return this

  apply: (propName, apply) ->
    apply = _.clone(apply)
    apply.operation = 'apply'
    apply.prop = propName
    @ops.push(apply)
    return this

  combine: ({ filter, sort, limit } = {}) ->
    combine = {
      operation: 'combine'
    }
    if sort
      combine.sort = sort

    if limit?
      combine.limit = limit

    @ops.push(combine)
    return this

  stage: (transform) ->
    throw new TypeError("transform must be a function") unless typeof transform is 'function'
    @ops.push({
      operation: 'stage'
      transform
    })
    return this

  pop: ->
    @ops.push({
      operation: 'pop'
    })
    return this


  plot: (plot) ->
    throw new TypeError("plot must be a function") unless typeof plot is 'function'
    @ops.push({
      operation: 'plot'
      plot
    })
    return this

  render: (selector, width, height) ->
    parent = d3.select(selector)
    throw new Error("could not find the provided selector") if parent.empty()
    throw new Error("bad size: #{width} x #{height}") unless width and height

    operations = @ops
    query = operations.filter(({operation}) -> operation in ['split', 'apply', 'combine'])
    @driver query, (err, res) ->
      if err
        alert("An error has occurred")
        throw err

      svg = parent.append('svg')
        .attr('width', width)
        .attr('height', height)

      segmentGroups = [[new Segment({
        parent: null
        node: svg
        stage: { type: 'rectangle', width, height }
        prop: res.prop
        splits: res.splits
      })]]

      for cmd in operations
        switch cmd.operation
          when 'split'
            segmentGroups = flatten(segmentGroups).map((segment) ->
              return segment.splits.map (sp) ->
                return new Segment({
                  parent: segment
                  node: segment.node.append('g')
                  stage: segment.getStage()
                  prop: sp.prop
                  splits: sp.splits
                })
            )

          when 'apply', 'combine'
            null # Do nothing, there is nothing to do on the client for those two :-)

          when 'layout'
            { layout } = cmd
            for segmentGroup in segmentGroups
              parentSegment = segmentGroup[0].parent
              throw new Error("You must split before calling layout") unless parentSegment
              layout(parentSegment, segmentGroup)

          when 'stage'
            { transform } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                transform(segment)

          when 'pop'
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                segment.popStage()

          when 'plot'
            { plot } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                plot(segment)

          else
            throw new Error("Unknown operation '#{cmd.operation}'")

      return

    return this


facet.visualize = (driver) -> new FacetJob(driver)

# Initialize drivers container
facet.driver = {}
