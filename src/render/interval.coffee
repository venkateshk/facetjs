"use strict"

{isInstanceOf} = require('../util')

class Interval
  constructor: (@start, @end) ->
    throw new Error("invalid start (is '#{@start}')") unless typeof @start.valueOf() is 'number'
    throw new Error("invalid end (is '#{@end}')") unless typeof @end.valueOf() is 'number'
    return

  valueOf: ->
    return @end - @start

  toString: ->
    if isInstanceOf(@start, Date)
      return "[#{@start.toISOString()}, #{@end.toISOString()})"
    else
      return "[#{@start.toPrecision(3)}, #{@end.toPrecision(3)})"

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


module.exports = Interval
