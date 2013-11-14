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

# This is copy pasted from chronology
# ToDo: remove this after properly resolving dependency
isTimezone = (tz) ->
  return typeof tz is 'string' and tz.indexOf('/') isnt -1

dummyObject = {}
