isValidStage = (stage) ->
  return Boolean(stage and typeof stage.type is 'string' and stage.node)

class Segment
  constructor: ({ @parent, stage, @prop, @splits }) ->
    throw new Error("invalid stage") unless isValidStage(stage)
    @_stageStack = [stage]
    @scale = {}
    @connector = {}

  getStage: ->
    return @_stageStack[@_stageStack.length - 1]

  setStage: (stage) ->
    throw new Error("invalid stage") unless isValidStage(stage)
    @_stageStack[@_stageStack.length - 1] = stage
    return

  pushStage: (stage) ->
    throw new Error("invalid stage") unless isValidStage(stage)
    @_stageStack.push(stage)
    return

  popStage: ->
    throw new Error("must have at least one stage") if @_stageStack.length < 2
    @_stageStack.pop()
    return

  _getDescription: ->
    description = ['prop values:']
    for propName, propValue of @prop
      description.push("  #{propName}: #{propValue}")

    description.push('', 'defined scales:')
    for scaleName, s of @scale
      description.push("  #{scaleName}")

    return description.join('\n')

  exposeStage: ->
    myStage = @getStage()
    # Ensure empty stage
    children = myStage.node.select('*')
    return unless children.empty()

    title = @_getDescription()

    plotFn = switch myStage.type
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

      else
        throw new Error("expose for #{myStage.type} needs to be implemented")

    plotFn(this)
    return
