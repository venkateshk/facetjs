class Space
  constructor: (@parent, @node, @type, @attr) ->
    @connector = {}
    @scale = {}
    return

  getScale: (scaleName) ->
    if @scale.hasOwnProperty(scaleName)
      return @scale[scaleName]
    else
      throw new Error("No such scale '#{scaleName}'") unless @parent
      return @parent.getScale(scaleName)

  getConnector: (connectorName) ->
    if @connector.hasOwnProperty(connectorName)
      return @connector[connectorName]
    else
      throw new Error("No such connector '#{connectorName}'") unless @parent
      return @parent.getConnector(connectorName)

  expose: (segment) ->
    children = @node.select('*')
    return unless children.empty()

    title = segment.getDescription()

    plotFn = switch @type
      when 'rectangle'
        facet.plot.box {
          fill: 'steelblue'
          stroke: 'black'
          opacity: 0.2
          title
          dash: 2
        }

      when 'point'
        facet.plot.circle {
          radius: 5
          fill: 'steelblue'
          stroke: 'black'
          opacity: 0.2
          title
          dash: 1
        }

      when 'line'
        facet.plot.line {
          stroke: 'black'
        }

      else
        throw new Error("expose for #{@type} needs to be implemented")

    plotFn(segment, this)
    return
