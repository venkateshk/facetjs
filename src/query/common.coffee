rangesIntersect = (range1, range2) ->
  if range2[1] < range1[0] or range2[0] > range1[1]
    return false
  else
    return range1[0] <= range2[1] and range2[0] <= range1[1]


smaller = (a, b) -> if a < b then a else b
larger  = (a, b) -> if a < b then b else a


specialJoin = (array, sep, lastSep) ->
  lengthMinus1 = array.length - 1
  return array.reduce (prev, now, index) -> prev + (if index < lengthMinus1 then sep else lastSep) + now

getValueOf = (d) -> d.valueOf()


class FacetOptions
  constructor: (options) ->
    for own k, v of options
      throw new TypeError("bad option value type (key: #{k})") unless typeof v in ['string', 'number']
      this[k] = v

  toString: ->
    parts = []
    for own k, v of this
      parts.push "#{k}:#{v}"
    return "[#{parts.join('; ')}]"

  valueOf: ->
    value = {}
    for own k, v of this
      value[k] = v
    return value

