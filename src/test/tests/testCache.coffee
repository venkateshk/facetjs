utils = require('../utils')

sqlRequester = require('../../mySqlRequester')
sqlDriver = require('../../sqlDriver')
driverCache = require('../../driverCache')

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

driverFns.mySql = mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
})

allowQuery = true
mySqlWrap = (query, callback) ->
  if not allowQuery
    throw new Error("query not allowed")

  mySql(query, callback)
  return

driverFns.mySqlCached = driverCache({
  driver: mySqlWrap
  timeAttribute: 'time'
  timeName: 'Time'
})

testDrivers = utils.makeDriverTest(driverFns)

# Sanity check
# exports["(sanity check) apply count"] = testDrivers {
#   drivers: ['mySql', 'mySqlCached']
#   query: [
#     { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
#     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
#     { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
#   ]
# }

# exports["(sanity check) split page; apply count; sort count ascending"] = testDrivers {
#   drivers: ['mySql', 'mySqlCached']
#   query: [
#     { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
#     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
#     { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
#     { operation: 'combine', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
#   ]
# }

# Cache Test
exports["split time; apply count; apply added"] = testDrivers {
  drivers: ['mySql', 'mySqlCached']
  query: [
    { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
    { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

exports["[cache tests on] split time; apply count; apply added"] = {
  setUp: (callback) ->
    allowQuery = false
    callback()

  tearDown: (callback) ->
    allowQuery = true
    callback()

  "split time; apply count": testDrivers {
    drivers: ['mySql', 'mySqlCached']
    query: [
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
    ]
  }
}


# Cache Test 2
exports["filter; split time; apply count; apply added"] = testDrivers {
  drivers: ['mySql', 'mySqlCached']
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

exports["[cache tests on] filter; split time; apply count"] = {
  setUp: (callback) ->
    allowQuery = false
    callback()

  tearDown: (callback) ->
    allowQuery = true
    callback()

  "filter; split time; apply count; apply added": testDrivers {
    drivers: ['mySql', 'mySqlCached']
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

  "filter; split time; apply count; apply added; combine time descending": testDrivers {
    drivers: ['mySql', 'mySqlCached']
    query: [
      { operation: 'filter', type: 'and', filters: [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      ]}
      { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
    ]
  }
}





# ToDo time filter within another time filter
# ToDo sort by time descending
# ToDo sort not by time
# ToDo limit



