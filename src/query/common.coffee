exports.specialJoin = (array, sep, lastSep) ->
  lengthMinus1 = array.length - 1
  return array.reduce (prev, now, index) -> prev + (if index < lengthMinus1 then sep else lastSep) + now


exports.getValueOf = (d) -> d.valueOf()


exports.find = (array, fn) ->
  for a, i in array
    return a if fn.call(array, a, i)
  return null


exports.dummyObject = {}
