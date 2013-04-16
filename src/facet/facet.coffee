getScaleAndSegments = (segment, scaleName) ->
  sourceSegment = segment
  hops = 0
  while true
    break if sourceSegment.scale[scaleName]
    sourceSegment = sourceSegment.parent
    hops++
    throw new Error("can not find scale '#{scaleName}'") unless sourceSegment

  # Get all of sources children on my level (my cousins)
  unifiedSegments = [sourceSegment]
  while hops > 0
    unifiedSegments = flatten(unifiedSegments.map((s) -> s.splits))
    hops--

  return {
    scale: sourceSegment.scale[scaleName]
    unifiedSegments
  }

class FacetJob
  constructor: (@selector, @width, @height, @driver) ->
    @ops = []
    @knownProps = {}
    @hasSplit = false
    @hasTransformed = false

  filter: (filter) ->
    filter = _.clone(filter)
    filter.operation = 'filter'
    @ops.push(filter)
    return this

  split: (name, split) ->
    split = _.clone(split)
    split.operation = 'split'
    split.name = name
    @ops.push(split)
    @hasSplit = true
    @hasTransformed = false
    @knownProps[name] = true
    return this

  layout: (layout) ->
    throw new Error("Must split before calling layout") unless @hasSplit
    throw new Error("Can not layout after a transform") if @hasTransformed
    throw new TypeError("layout must be a function") unless typeof layout is 'function'
    @ops.push({
      operation: 'layout'
      layout
    })
    return this

  apply: (name, apply) ->
    apply = _.clone(apply)
    apply.operation = 'apply'
    apply.name = name
    @ops.push(apply)
    @knownProps[name] = true
    return this

  scale: (name, scale) ->
    throw new TypeError("not a valid scale") unless typeof scale.domain is 'function'
    @ops.push({
      operation: 'scale'
      name
      scale
    })
    return this

  domain: (name, domain) ->
    @ops.push({
      operation: 'domain'
      name
      domain
    })
    return this

  range: (name, range) ->
    @ops.push({
      operation: 'range'
      name
      range
    })
    return this

  combine: ({ combine, sort, limit } = {}) ->
    # ToDo: implement filter
    combineCmd = {
      operation: 'combine'
      combine
    }
    if sort
      if not @knownProps[sort.prop]
        throw new Error("can not sort on unknown prop '#{sort.prop}'")
      combineCmd.sort = sort
      combineCmd.sort.compare ?= 'natural'

    if limit?
      combineCmd.limit = limit

    @ops.push(combineCmd)
    return this

  transform: (transform) ->
    throw new TypeError("transform must be a function") unless typeof transform is 'function'
    @ops.push({
      operation: 'transform'
      transform
    })
    @hasTransformed = true
    return this

  untransform: ->
    @ops.push({
      operation: 'untransform'
    })
    return this


  plot: (plot) ->
    throw new TypeError("plot must be a function") unless typeof plot is 'function'
    @ops.push({
      operation: 'plot'
      plot
    })
    return this

  getQuery: ->
    return @ops.filter(({operation}) -> operation in ['filter', 'split', 'apply', 'combine'])

  render: ->
    parent = d3.select(@selector)
    width = @width
    height = @height
    throw new Error("could not find the provided selector") if parent.empty()

    svg = parent.append('svg').attr {
      class: 'facet loading'
      width
      height
    }

    operations = @ops
    @driver @getQuery(), (err, res) ->
      svg.classed('loading', false)
      if err
        svg.classed('error', true)
        alert("An error has occurred: " + if typeof err is 'string' then err else err.message)
        return

      segmentGroups = [[new Segment({
        parent: null
        stage: {
          node: svg
          type: 'rectangle'
          width
          height
        }
        prop: res.prop
        splits: res.splits
      })]]

      for cmd in operations
        switch cmd.operation
          when 'split'
            segmentGroups = flatten(segmentGroups).map((segment) ->
              return segment.splits = segment.splits.map ({ prop, splits }) ->
                stage = _.clone(segment.getStage())
                stage.node = stage.node.append('g')
                for key, value of prop
                  if Array.isArray(value)
                    prop[key] = Interval.fromArray(value)
                return new Segment({
                  parent: segment
                  stage: stage
                  prop
                  splits
                })
            )

          when 'filter', 'apply', 'combine'
            null # Do nothing, there is nothing to do on the renderer for those :-)

          when 'scale'
            { name, scale } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                segment.scale[name] = scale

          when 'domain'
            { name, domain } = cmd
            { scale, unifiedSegments } = getScaleAndSegments(segmentGroups[0][0], name)
            throw new Error("Scale '#{name}' domain can't be trained") unless scale.domain
            scale.domain(unifiedSegments, domain)

          when 'range'
            { name, range } = cmd
            { scale, unifiedSegments } = getScaleAndSegments(segmentGroups[0][0], name)
            throw new Error("Scale '#{name}' range can't be trained") unless scale.range
            scale.range(unifiedSegments, range)

          when 'layout'
            { layout } = cmd
            for segmentGroup in segmentGroups
              parentSegment = segmentGroup[0].parent
              throw new Error("must split before calling layout") unless parentSegment
              pseudoStages = layout(parentSegment, segmentGroup)
              for segment, i in segmentGroup
                pseudoStage = pseudoStages[i]
                pseudoStage.stage.node = segment.getStage().node
                  .attr('transform', "translate(#{pseudoStage.x},#{pseudoStage.y})")
                segment.setStage(pseudoStage.stage)

          when 'transform'
            { transform } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                pseudoStage = transform(segment)
                pseudoStage.stage.node = segment.getStage().node.append('g')
                  .attr('transform', "translate(#{pseudoStage.x},#{pseudoStage.y})")
                segment.pushStage(pseudoStage.stage)


          when 'untransform'
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


facet.define = (selector, width, height, driver) ->
  throw new Error("bad size: #{width} x #{height}") unless width and height
  return new FacetJob(selector, width, height, driver)

