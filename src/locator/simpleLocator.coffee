integerRegExp = /^\d+$/

module.exports = (arg) ->
  if typeof arg is 'string'
    resource = arg
  else
    {resource, defaultPort} = arg

  throw new Error("must have resource") unless resource

  locations = resource.split(';').map((locationString) ->
    parts = locationString.split(':')
    throw new Error("invalid resource part '#{locationString}'") unless parts.length in [1, 2]

    location = {
      host: parts[0]
    }
    if parts.length is 2
      throw new Error("invalid port in resource '#{parts[1]}'") unless integerRegExp.test(parts[1])
      location.port = Number(parts[1])
    else if defaultPort
      location.port = defaultPort

    return location
  )

  return (callback) ->
    callback(null, locations[Math.floor(Math.random() * locations.length)])
    return
