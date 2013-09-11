class Segment
  constructor: (@parent, prop, @splits) ->
    for key, value of prop
      if Array.isArray(value)
        prop[key] = Interval.fromArray(value)

    @prop = prop
    @scale = {}

  getProp: (propName) ->
    if @prop.hasOwnProperty(propName)
      return @prop[propName]
    else
      throw new Error("No such prop '#{propName}'") unless @parent
      return @parent.getProp(propName)

  getScale: (scaleName) ->
    if @scale.hasOwnProperty(scaleName)
      return @scale[scaleName]
    else
      throw new Error("No such scale '#{scaleName}'") unless @parent
      return @parent.getScale(scaleName)

  getDescription: ->
    description = ['prop values:']
    for propName, propValue of @prop
      description.push("  #{propName}: #{String(propValue)}")

    description.push('', 'defined scales:')
    for scaleName, s of @scale
      description.push("  #{scaleName}")

    return description.join('\n')


