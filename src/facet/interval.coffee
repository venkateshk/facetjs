class Interval
  constructor: (@start, @end) ->
    return

  transform: (fn) ->
    null

  valueOf: ->
    return @end - @start

Interval.fromArray = (arr) ->
  throw new Error("Interval must have length of 2 (is: #{arr.length})") unless arr.length is 2
  [start, end] = arr
  startType = typeof start
  endType = typeof end
  if startType is 'string' and endType is 'string'
    startDate = new Date(start)
    throw new Error("bad start date '#{start}'") if isNaN(startDate.valueOf())
    endDate = new Date(end)
    throw new Error("bad end date '#{end}'") if isNaN(endDate.valueOf())
    return new Interval(startDate, endDate)

  return new Interval(start, end)
