exports.specialJoin = (array, sep, lastSep) ->
  lengthMinus1 = array.length - 1
  return array.reduce (prev, now, index) -> prev + (if index < lengthMinus1 then sep else lastSep) + now


exports.getValueOf = (d) -> d.valueOf()


# This is copy pasted from chronology
# ToDo: remove this after properly resolving dependency
exports.isTimezone = (tz) ->
  return typeof tz is 'string' and tz.indexOf('/') isnt -1


exports.find = (array, fn) ->
  for a, i in array
    return a if fn.call(array, a, i)
  return null


exports.dummyObject = {}
