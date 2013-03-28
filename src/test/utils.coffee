async = require('async')

uniformizeResults = (result) ->
  if not result?.prop
    return result

  prop = {}
  for name, value of result.prop
    continue unless result.prop.hasOwnProperty(name)
    if typeof value is 'number' and value isnt Math.floor(value)
      prop[name] = value.toFixed(3)
    else if Array.isArray(value) and
          typeof value[0] is 'number' and
          typeof value[1] is 'number' and
          (value[0] isnt Math.floor(value[0]) or value[1] isnt Math.floor(value[1]))
      prop[name] = [value[0].toFixed(3), value[1].toFixed(3)]
    else
      prop[name] = value

  ret = { prop }
  if result.splits
    ret.splits = result.splits.map(uniformizeResults)
  return ret

exports.makeDriverTest = (driverFns) ->
  return ({drivers, query}) -> (test) ->
    throw new Error("must have at least two drivers") if drivers.length < 2
    test.expect(drivers.length)

    driversToTest = drivers.map (driverName) ->
      driverFn = driverFns[driverName]
      throw new Error("no such driver #{driverName}") unless driverFn
      return (callback) ->
        driverFn(query, callback)
        return

    async.parallel driversToTest, (err, results) ->
      test.ifError(err)
      results = results.map(uniformizeResults)

      i = 1
      while i < drivers.length
        test.deepEqual(results[0], results[i], "results of '#{drivers[0]}' and '#{drivers[i]}' do not match")
        i++
      test.done()
      return