utils = require('../utils')

sqlRequester = require('../../mySqlRequester')
sqlDriver = require('../../sqlDriver')
DriverCacheWrapper = require('../../driverCache').DriverCacheWrapper

# Set up drivers
driverFns = {}

# Simple
# diamondsData = require('../../../data/diamonds.js')
# driverFns.simple = simpleDriver(diamondsData)

verbose = false

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  user: 'root'
  password: 'root'
  database: 'facet'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filter: {
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
    ]
  }
})

cache = new DriverCacheWrapper(driverFns.mySql, 'time')

driverFns.cache = cache.getData.bind(cache)

testDrivers = utils.makeDriverTest(driverFns)


exports["apply count"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["split time; apply count; apply added"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

# exports["split time; apply count"] = testDrivers {
#   drivers: ['mySql', 'cache']
#   query: [
#     { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
#     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
#     { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
#   ]
# }

# exports["apply count"] = testDrivers {
#   drivers: ['mySql', 'cache']
#   query: [
#     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
#     { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
#   ]
# }
