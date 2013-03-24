async = require('async')

druidRequester = require('../druidRequester').requester
sqlRequester = require('../mySqlRequester').requester

simpleDriver = require('../simpleDriver')
druidDriver = require('../druidDriver')
sqlDriver = require('../sqlDriver')

# Set up drivers
driver = {}

# Simple
diamondsData = require('../../data/diamonds.js')
driver.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  user: 'root'
  password: 'root'
  database: 'facet'
})

driver.mySql = sqlDriver({
  requester: sqlPass
  table: 'diamonds'
  filters: null
})

# # Druid
# druidPass = druidRequester({
#   host: '10.60.134.138'
#   port: 8080
#   path: '/druid/v2/'
# })

# druidDrive = druidDriver({
#   requester: druidPass
#   dataSource: context.dataSource
#   interval: context.interval.map((d) -> new Date(d))
#   filters: null
# })

uniformizeResults = (result) ->
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

testDrivers = ({drivers, query}) -> (test) ->
  throw new Error("must have at least two drivers") if drivers.length < 2
  test.expect(drivers.length)

  driversToTest = drivers.map (driverName) ->
    throw new Error("no such driver #{driverName}") unless driver[driverName]
    return (callback) ->
      driver[driverName](query, callback)
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



exports["apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'apply', name: 'Count',  aggregate: 'count' }
  ]
}

exports["many applies"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'apply', name: 'Constant 42',  aggregate: 'constant', value: '42' }
    { operation: 'apply', name: 'Count',  aggregate: 'count' }
    { operation: 'apply', name: 'Total Price',  aggregate: 'sum', attribute: 'price' }
    { operation: 'apply', name: 'Avg Price',  aggregate: 'average', attribute: 'price' }
    { operation: 'apply', name: 'Min Price',  aggregate: 'min', attribute: 'price' }
    { operation: 'apply', name: 'Max Price',  aggregate: 'max', attribute: 'price' }
    { operation: 'apply', name: 'Num Cuts',  aggregate: 'uniqueCount', attribute: 'cut' }
  ]
}

exports["split cut; no apply"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'combine', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split cut; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
  ]
}

exports["split carat; apply count"] = testDrivers {
  drivers: ['simple', 'mySql']
  query: [
    { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0, attribute: 'carat' }
    { operation: 'apply', name: 'Count', aggregate: 'count' }
    { operation: 'combine', sort: { prop: 'Carat', compare: 'natural', direction: 'descending' } }
  ]
}
