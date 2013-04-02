utils = require('../utils')

druidRequester = require('../../druidRequester')
sqlRequester = require('../../mySqlRequester')

simpleDriver = require('../../simpleDriver')
sqlDriver = require('../../sqlDriver')
druidDriver = require('../../druidDriver')

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

sqlPass = utils.wrapVerbose(sqlPass) if verbose

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  host: '10.60.134.138'
  port: 8080
  path: '/druid/v2/'
})

druidPass = utils.wrapVerbose(druidPass) if verbose

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  filter: {
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
    ]
  }
})

testDrivers = utils.makeDriverTest(driverFns)

exports["apply count"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["filter; apply count"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
  ]
}

exports["apply arithmetic"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    {
      operation: 'apply'
      name: 'Added + Delted'
      arithmetic: 'add'
      operands: [
        { aggregate: 'sum', attribute: 'added' }
        { aggregate: 'sum', attribute: 'deleted' }
      ]
    }
    {
      operation: 'apply'
      name: 'Added - Delted'
      arithmetic: 'subtract'
      operands: [
        { aggregate: 'sum', attribute: 'added' }
        { aggregate: 'sum', attribute: 'deleted' }
      ]
    }
  ]
}

exports["split time; apply count"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Time', bucket: 'time', attribute: 'time', duration: 'hour', timezone: 'Etc/UTC' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
  ]
}

# Test timezone support

exports["split page; apply count; sort count descending"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
  ]
}

exports["split language; apply count; sort count descending > split page; apply count; sort count descending"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
  ]
}

exports["split page; apply count; sort count ascending"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
  ]
}

exports["filter language=en; split page; apply count; sort count ascending"] = testDrivers {
  drivers: ['mySql', 'druid']
  query: [
    { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
    { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
    { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
    { operation: 'combine', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
  ]
}

