`(typeof window === 'undefined' ? {} : window)['driverUtil'] = (function(module, require){"use strict"; var exports = module.exports`

# -----------------------------------------------------
timezoneJS = require('timezone-js') or require('./timezoneJS')
tz_info = require('../utils/timezone') or require('mmx_tz_info')

tz = timezoneJS.timezone
tz.loadingScheme = tz.loadingSchemes.MANUAL_LOAD
tz.loadZoneDataFromObject(tz_info)

# Flatten an array of array in to a single array
# flatten([[1,3], [3,6,7]]) => [1,3,3,6,7]
exports.flatten = flatten = (ar) -> Array::concat.apply([], ar)

# Trims the array in place
exports.inPlaceTrim = (array, n) ->
  return if array.length < n
  array.splice(n, array.length - n)
  return


# Filter the array in place
exports.inPlaceFilter = (array, fn) ->
  i = 0
  while i < array.length
    if fn.call(array, array[i], i)
      i++
    else
      array.splice(i, 1)
  return


# Filter and map (how is this method not part of native JS?!)
exports.filterMap = (array, fn) ->
  ret = []
  for a in array
    v = fn(a)
    continue if typeof v is 'undefined'
    ret.push(v)
  return ret


getPropFromSegment = (segment, prop) ->
  return null unless segment and segment.prop
  return segment.prop[prop] or getPropFromSegment(segment.parent, prop)

# Clean segment - remove everything in the segment that starts with and underscore
exports.cleanProp = (prop) ->
  for key of prop
    if key[0] is '_'
      delete prop[key]
  return

exports.cleanSegments = cleanSegments = (segment) ->
  delete segment.parent
  delete segment._filter
  delete segment._raw

  prop = segment.prop
  for key of prop
    if key[0] is '_'
      delete prop[key]

  splits = segment.splits
  if splits
    for split in splits
      cleanSegments(split)

  return segment

createTabularHelper = (node, rangeFn, history) ->
  newHistory = {}
  for k, v of history
    newHistory[k] = v
  # Base case
  for k, v of node.prop
    v = rangeFn(v, k) if Array.isArray(v)
    newHistory[k] = v
  if node.splits?
    return flatten(node.splits.map((split) -> createTabularHelper(split, rangeFn, newHistory)))
  else
    return [newHistory]

exports.createTabular = createTabular = (node, rangeFn) ->
  rangeFn ?= (range) -> range
  return [] unless node.prop or node.splits
  return createTabularHelper(node, rangeFn, {})

class exports.Table
  constructor: ({root, @query}) ->
    @columns = createColumns(@query)
    # console.log root
    # console.log createTabular(root)
    @data = createTabular(root)
    @dimensionSize = @query.filter((op) -> op.operation is 'split').length
    @metricSize = @query.filter((op) -> op.operation is 'apply').length

  toTabular: (separator, rangeFn) ->
    _this = this
    header = @columns.map((column) -> return '\"' + column + '\"').join(separator)

    rangeFn or= (range) ->
      if range[0] instanceof Date
        range = range.map((range) -> range.toISOString())
      return range.join('-')

    content = @data.map((row) ->
      ret = []
      _this.columns.forEach((column, i) ->
        datum = row[column]
        if i < _this.dimensionSize
          if datum?
            if Array.isArray(datum)
              ret.push('\"' + rangeFn(datum).replace(/\"/, '\"\"') + '\"')
            else
              ret.push('\"' + datum.replace(/\"/, '\"\"') + '\"')
          else
            ret.push('\"\"')
        else
          if datum?
            ret.push('\"' + datum + '\"')
          else
            ret.push('\"0\"')
      )
      return ret.join(separator)
    ).join('\r\n')
    return header + '\r\n' + content

  columnMap: (mappingFunction) ->
    @data = @data.map((row) ->
      convertedRow = {}
      for k, v of row
        convertedRow[mappingFunction(k)] = row[k]

      return convertedRow
    )

    @columns = @columns.map(mappingFunction)
    return

exports.createColumns = createColumns = (query) ->
  split = flatten(query.filter((op) -> op.operation is 'split').map((op) ->
    if op.bucket is 'tuple'
      return op.splits.map((o) -> o.name)
    else
      return [op.name]
  ))
  tempApply = query.filter((op) -> op.operation is 'apply').map((op) -> op.name)
  apply = []
  for applyName in tempApply
    if apply.indexOf(applyName) >= 0
      apply.splice(apply.indexOf(applyName), 1)
    apply.push applyName
  return split.concat(apply)

# Flattens the split tree into an array
#
# @param {SplitTree} root - the root of the split tree
# @param {prepend,append,none} order - what to do with the root of the tree
# @return {Array(SplitTree)} the tree nodes in the order specified

exports.flattenTree = (root, order) ->
  throw new TypeError('must have a tree') unless root
  throw new TypeError('order must be on of prepend, append, or none') unless order in ['prepend', 'append', 'none']
  flattenTreeHelper(root, order, result = [])
  return result

flattenTreeHelper = (root, order, result) ->
  result.push(root) if order is 'prepend'

  if root.splits
    for split in root.splits
      flattenTreeHelper(split, order, result)

  result.push(root) if order is 'append'
  return


# Adds parents to a split tree in place
#
# @param {SplitTree} root - the root of the split tree
# @param {SplitTree} parent [null] - the parent for the initial node
# @return {SplitTree} the input tree (with parent pointers)

exports.parentify = parentify = (root, parent = null) ->
  root.parent = parent
  if root.splits
    for split in root.splits
      parentify(split, root)
  return root


isTimezone = (tz) ->
  return typeof tz is 'string' and tz.indexOf('/') isnt -1

exports.adjust = {
  second: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      if dt.getMilliseconds()
        dt.setMilliseconds(1000)
      return dt
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      dt.setMilliseconds(0)
      return dt
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Seconds do not actually need a timezone because all timezones align on seconds... for now...
      dt = new Date(dt)
      dt.setMilliseconds(Math.round(dt.getMilliseconds() / 1000 ) * 1000)
      return dt
  }
  minute: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      if dt.getMilliseconds() or dt.getSeconds()
        dt.setSeconds(60, 0)
      return dt
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      dt.setSeconds(0, 0)
      return dt
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Minutes do not actually need a timezone because all timezones align on minutes... for now...
      dt = new Date(dt)
      dt.setSeconds(Math.round(dt.getSeconds() / 60 ) * 60, 0)
      return dt
  }
  hour: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      if dt.getMilliseconds() or dt.getSeconds() or dt.getMinutes()
        dt.setMinutes(60, 0, 0)
      return new Date(dt.valueOf())
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      dt.setMinutes(0, 0, 0)
      return new Date(dt.valueOf())
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      # Not all timezones align on hours! (India)
      dt = new timezoneJS.Date(dt, tz)
      dt.setMinutes(Math.round(dt.getMinutes() / 60 ) * 60, 0, 0)
      return new Date(dt.valueOf())
  }
  day: {
    ceil: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      if dt.getMilliseconds() or dt.getSeconds() or dt.getMinutes() or dt.getHours()
        dt.setHours(24, 0, 0, 0)
      return new Date(dt.valueOf())
    floor: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      dt.setHours(0, 0, 0, 0)
      return new Date(dt.valueOf())
    round: (dt, tz) ->
      throw new TypeError("#{tz} is not a valid timezone") unless isTimezone(tz)
      dt = new timezoneJS.Date(dt, tz)
      dt.setHours(Math.round(dt.getHours() / 60 ) * 60, 0, 0, 0)
      return new Date(dt.valueOf())
  }
}

exports.convertToTimezoneJS = (timerange, timezone) ->
  return timerange.map((time) -> new timezoneJS.Date(time, timezone))

# -----------------------------------------------------
# Handle commonJS crap
`return module.exports; }).call(this,
  (typeof module === 'undefined' ? {exports: {}} : module),
  (typeof require === 'undefined' ? function (modulePath) {
    var moduleParts = modulePath.split('/');
    return window[moduleParts[moduleParts.length - 1]];
  } : require)
)`
