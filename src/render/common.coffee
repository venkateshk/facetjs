exports.useLiteral = useLiteral = (value) -> return ->
  return value

exports.wrapLiteral = (arg) ->
  return if typeof arg in ['undefined', 'function'] then arg else useLiteral(arg)
