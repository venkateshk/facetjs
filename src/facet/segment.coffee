isValidStage = (stage) ->
  return Boolean(stage and typeof stage.type is 'string' and stage.node)

class Segment
  constructor: ({ @parent, stage, @prop, @splits }) ->
    throw new Error("invalid stage") unless isValidStage(stage)
    @_stageStack = [stage]
    @scale = {}

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
