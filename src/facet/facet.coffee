
class FacetJob
  constructor: (@selector, @width, @height, @driver) ->
    @ops = []
    @knownProps = {}
    @hasSplit = false
    @hasTransformed = false

  split: (propName, split) ->
    split = _.clone(split)
    split.operation = 'split'
    split.prop = propName
    @ops.push(split)
    @hasSplit = true
    @hasTransformed = false
    @knownProps[propName] = true
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

  apply: (propName, apply) ->
    apply = _.clone(apply)
    apply.operation = 'apply'
    apply.prop = propName
    @ops.push(apply)
    @knownProps[propName] = true
    return this

  scale: (name, scale) ->
    throw new TypeError("scale must be a function") unless typeof scale is 'function'
    @ops.push({
      operation: 'scale'
      name
      scale
    })
    return this

  train: (name, param) ->
    @ops.push({
      operation: 'train'
      name
      param
    })
    return this

  combine: ({ filter, sort, limit } = {}) ->
    # ToDo: implement filter
    combine = {
      operation: 'combine'
    }
    if sort
      if not @knownProps[sort.prop]
        throw new Error("can not sort on unknown prop '#{sort.prop}'")
      combine.sort = sort
      combine.sort.compare ?= 'natural'

    if limit?
      combine.limit = limit

    @ops.push(combine)
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
    return @ops.filter(({operation}) -> operation in ['split', 'apply', 'combine'])

  render: ->
    parent = d3.select(@selector)
    width = @width
    height = @height
    throw new Error("could not find the provided selector") if parent.empty()

    svg = parent.append('svg')
      .attr('width', width)
      .attr('height', height)

    operations = @ops
    @driver @getQuery(), (err, res) ->
      if err
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

          when 'apply', 'combine'
            null # Do nothing, there is nothing to do on the renderer for those two :-)

          when 'scale'
            { name, scale } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                segment.scale[name] = {
                  train: scale
                }

          when 'train'
            { name, param } = cmd

            sourceSegment = segmentGroups[0][0]
            hops = 0
            while true
              break if sourceSegment.scale[name]
              sourceSegment = sourceSegment.parent
              hops++
              throw new Error("can not find scale '#{name}'") unless sourceSegment

            # Get all of sources children on my level (my cousins)
            unifiedSegments = [sourceSegment]
            while hops > 0
              unifiedSegments = flatten(unifiedSegments.map((s) -> s.splits))
              hops--

            if not sourceSegment.scale[name].train
              throw new Error("Scale '#{name}' already trained")

            sourceSegment.scale[name] = sourceSegment.scale[name].train(unifiedSegments, param)

          when 'layout'
            { layout } = cmd
            for segmentGroup in segmentGroups
              parentSegment = segmentGroup[0].parent
              throw new Error("must split before calling layout") unless parentSegment
              psudoStages = layout(parentSegment, segmentGroup)
              for segment, i in segmentGroup
                psudoStage = psudoStages[i]
                stageX = psudoStage.x
                stageY = psudoStage.y
                stage = segment.getStage()
                delete psudoStage.x
                delete psudoStage.y
                psudoStage.node = stage.node
                  .attr('transform', "translate(#{stageX},#{stageY})")
                segment.setStage(psudoStage)

          when 'transform'
            { transform } = cmd
            for segmentGroup in segmentGroups
              for segment in segmentGroup
                psudoStage = transform(segment)
                stageX = psudoStage.x
                stageY = psudoStage.y
                stage = segment.getStage()
                delete psudoStage.x
                delete psudoStage.y
                psudoStage.node = stage.node.append('g')
                  .attr('transform', "translate(#{stageX},#{stageY})")
                segment.pushStage(psudoStage)


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

