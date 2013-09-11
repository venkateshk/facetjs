pseudoSpaceToTransform = ({x, y, a}) ->
  transformStr = "translate(#{x},#{y})"
  transformStr += " rotate(#{a})" if a
  return transformStr

class FacetVis
  constructor: ->
    if arguments.length is 4
      [@selector, @width, @height, @driver] = arguments
      @knownProps = {}
    else
      [@parent, @from, @knownProps] = arguments
    @ops = []

  _ensureCommandOrder: (self, follow, allow = []) ->
    i = @ops.length - 1
    while i >= 0
      op = @ops[i]
      return if op.operation in follow
      if op.operation not in allow
        throw new Error("#{self} can not follow #{op.operation} (has to follow #{follow.join(', ')})")
      i--
    if '$start' not in follow
      throw new Error("#{self} can not be an initial command (has to follow #{follow.join(', ')})")
    return

  filter: (filter) ->
    @_ensureCommandOrder('filter'
      ['$start']
      ['transform']
    )
    filter = _.clone(filter)
    filter.operation = 'filter'
    @ops.push(filter)
    return this

  split: (name, split) ->
    @_ensureCommandOrder('split'
      ['$start', 'filter', 'split', 'apply', 'combine']
      ['layout', 'scale', 'domain', 'range', 'transform', 'untransform', 'plot', 'connector', 'connect']
    )
    split = _.clone(split)
    split.operation = 'split'
    split.name = name
    @ops.push(split)
    @knownProps[name] = true
    return this

  apply: (name, apply) ->
    @_ensureCommandOrder('apply'
      ['$start', 'split', 'apply']
      ['scale', 'domain', 'range', 'transform', 'untransform', 'plot']
    )
    apply = _.clone(apply)
    apply.operation = 'apply'
    apply.name = name
    @ops.push(apply)
    @knownProps[name] = true
    return this

  combine: ({method, sort, limit}) ->
    @_ensureCommandOrder('combine'
      ['split', 'apply']
    )
    combineCmd = {
      operation: 'combine'
      method
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

  layout: (layout) ->
    @_ensureCommandOrder('layout'
      ['split', 'apply', 'combine']
      ['scale', 'domain']
    )
    throw new TypeError("layout must be a function") unless typeof layout is 'function'
    subVis = new FacetVis(this, 'layout', @knownProps)
    @ops.push({
      operation: 'layout'
      layout
      vis: subVis
    })
    return subVis

  unlayout: ->
    throw new Error("can not unlayout on the base") unless @parent
    throw new Error("unmatched nesting (nested with #{@from})") unless @from is 'unlayout'
    return @parent

  scale: (name, scale) ->
    throw new TypeError("not a valid scale") unless typeof scale is 'function'
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

  branch: (data) ->
    @_ensureCommandOrder('branch'
      ['$start']
      ['domain']
    )
    # create a branch split segment

  unbranch: ->
    @_ensureCommandOrder('unbranch'
      ['branch']
      ['domain']
    )
    # go back to the main segment

  transform: (transform) ->
    throw new TypeError("transform must be a function") unless typeof transform is 'function'
    subVis = new FacetVis(this, 'transform', @knownProps)
    @ops.push({
      operation: 'transform'
      transform
      vis: subVis
    })
    return subVis

  untransform: ->
    throw new Error("can not untransform on the base") unless @parent
    throw new Error("unmatched nesting (nested with #{@from})") unless @from is 'transform'
    return @parent

  plot: (plot) ->
    throw new TypeError("plot must be a function") unless typeof plot is 'function'
    @ops.push({
      operation: 'plot'
      plot
    })
    return this

  connector: (name, connector) ->
    throw new TypeError("not a valid connector") unless typeof connector is 'function'
    @ops.push({
      operation: 'connector'
      name
      connector
    })
    return this

  connect: (name) ->
    @ops.push({
      operation: 'connect'
      name
    })
    return this

  getFlatOperations: ->
    operations = []
    for op in @ops
      operations.push(op)
      if op.operation in ['layout', 'transform']
        Array::push.apply(operations, op.vis.getFlatOperations())
        operations.push({ operation: 'un' + op.operation })

    return operations

  render: (expose, done) ->
    return @parent.render(expose, done) if @parent

    if typeof expose is 'function'
      done = expose
      expose = false

    parent = d3.select(@selector)
    width = @width
    height = @height
    throw new Error("could not find the provided selector") if parent.empty()

    svg = parent.append('svg').attr {
      class: 'facet loading'
      width
      height
    }

    operations = @getFlatOperations()

    querySpec = operations.filter ({operation}) ->
      return operation in ['filter', 'split', 'apply', 'combine']

    @driver { query: new FacetQuery(querySpec) }, (err, res) ->
      svg.classed('loading', false)
      if err
        svg.classed('error', true)
        errorMerrage = "An error has occurred: " + if typeof err is 'string' then err else err.message
        if typeof alert is 'function' then alert(errorMerrage) else console.log(errorMerrage)
        return

      stateStack = [{
        spaces: [new Space(null, svg, 'rectangle', { width, height })]
        segments: [new Segment(null, res.prop, res.splits)]
      }]
      allStates = stateStack.slice()

      for cmd in operations
        curState = stateStack[stateStack.length - 1]

        if curState.segments.length isnt curState.spaces.length
          console.log cmd
          throw "sanity check"

        switch cmd.operation
          when 'split'
            throw new Error("Can not split (again) in pregnant state") if curState.pregnant
            segmentGroups = curState.segments.map (segment) ->
              return segment.splits = segment.splits.map ({ prop, splits }) ->
                return new Segment(segment, prop, splits)

            curState.pregnant = true
            curState.segmentGroups = segmentGroups
            curState.nextSegments = flatten(segmentGroups)

          when 'filter', 'apply', 'combine'
            null # Do nothing, there is nothing to do on the renderer for those :-)

          when 'scale'
            throw new Error("Can not declare scales in pregnant state") if curState.pregnant
            { name, scale } = cmd
            for segment, i in curState.segments
              space = curState.spaces[i]
              myScale = scale()
              throw new TypeError("not a valid scale") unless typeof myScale.domain is 'function'
              # Since scales connect the data space to the physical space both need to know about them
              segment.scale[name] = myScale
              space.scale[name] = myScale

          when 'domain'
            { name, domain } = cmd

            curScale = null
            for segment in (curState.nextSegments or curState.segments)
              c = segment.getScale(name)
              if c is curScale
                curBatch.push(segment)
              else
                if curScale
                  curScale.domain(curBatch, domain)
                curScale = c
                curBatch = [segment]

            if curScale
              curScale.domain(curBatch, domain)

          when 'range'
            throw new Error("Can not train range in pregnant state") if curState.pregnant
            { name, range } = cmd

            curScale = null
            for space in curState.spaces
              c = space.getScale(name)
              if c is curScale
                curBatch.push(space)
              else
                if curScale
                  throw new Error("Scale '#{name}' range can not be trained") unless curScale.range
                  curScale.range(curBatch, range)
                curScale = c
                curBatch = [space]

            if curScale
              throw new Error("Scale '#{name}' range can not be trained") unless curScale.range
              curScale.range(curBatch, range)

          when 'layout'
            throw new Error("Must be in pregnant state to layout") unless curState.pregnant
            { layout } = cmd
            newSpaces = []
            for segmentGroup, i in curState.segmentGroups
              space = curState.spaces[i]
              pseudoSpaces = layout(segmentGroup, space)
              for pseudoSpace in pseudoSpaces
                newSpaces.push(new Space(
                  space
                  space.node.append('g').attr('transform', pseudoSpaceToTransform(pseudoSpace))
                  pseudoSpace.type
                  pseudoSpace.attr
                ))

            nextState = {
              spaces: newSpaces
              segments: curState.nextSegments
            }
            stateStack.push(nextState)
            allStates.push(nextState)

          when 'unlayout'
            stateStack.pop()

          when 'transform'
            { transform } = cmd
            nextState = {}
            nextState[k] = v for k, v of curState

            nextState.spaces = curState.spaces.map (space, i) ->
              segment = curState.segments[i]
              pseudoSpace = transform(segment, space)
              return new Space(
                space
                space.node.append('g').attr('transform', pseudoSpaceToTransform(pseudoSpace))
                pseudoSpace.type
                pseudoSpace.attr
              )

            stateStack.push(nextState)
            allStates.push(nextState)

          when 'untransform'
            stateStack.pop()

          when 'plot'
            { plot } = cmd
            for segment, i in curState.segments
              space = curState.spaces[i]
              plot(segment, space)

          when 'connector'
            { name, connector } = cmd
            for segment, i in curState.segments
              space = curState.spaces[i]
              space.connector[name] = connector(segment, space)

          when 'connect'
            { name } = cmd

            curConnector = null
            for space in curState.spaces
              c = space.getConnector(name)
              if c is curConnector
                curBatch.push(space)
              else
                if curConnector
                  curConnector(curBatch)
                curConnector = c
                curBatch = [space]

            if curConnector
              curConnector(curBatch)

          else
            throw new Error("Unknown operation '#{cmd.operation}'")

      if typeof done is 'function'
        rootSegment = stateStack[0].segments[0]
        done.call(rootSegment, rootSegment)

      if expose
        for curState in allStates
          for segment, i in curState.segments
            curState.spaces[i].expose(segment)

      return

    return this


facet.define = (selector, width, height, driver) ->
  throw new Error("bad size: #{width} x #{height}") unless width and height
  return new FacetVis(selector, width, height, driver)


