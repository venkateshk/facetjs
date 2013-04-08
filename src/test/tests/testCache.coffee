utils = require('../utils')

sqlRequester = require('../../mySqlRequester')
sqlDriver = require('../../sqlDriver')
cache = require('../../driverCache')

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
})

driverFns.cache = cache({driver: driverFns.mySql, timeAttribute: 'time', timeName: 'Time'})

testDrivers = utils.makeDriverTest(driverFns)

# Sanity check
exports["apply count"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["split page; apply count; sort count ascending"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
  ]
}

# Cache Test
exports["split time; apply count; apply added"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

exports["split time; apply count"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

# Cache Test 2
exports["filter; split time; apply count"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'filter', type: 'and', filters: [
      { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    ]}
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

exports["filter; split time; apply count; apply added"] = testDrivers {
  drivers: ['mySql', 'cache']
  query: [
    { operation: 'filter', type: 'and', filters: [
      { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    ]}
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}
