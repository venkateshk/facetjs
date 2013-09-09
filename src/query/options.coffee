class FacetOptions
  constructor: (options) ->
    for own k, v of options
      throw new TypeError("bad option value type (key: #{k})") unless typeof v in ['string', 'number']
      this[k] = v

  toString: ->
    parts = []
    for own k, v of this
      parts.push "#{k}:#{v}"
    return "[#{parts.sort().join('; ')}]"

  valueOf: ->
    value = {}
    for own k, v of this
      value[k] = v
    return value

  isEqual: (other) ->
    return Boolean(other) and @toString() is other.toString()

