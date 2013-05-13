chai = require("chai")
expect = chai.expect
utils = require('../utils')

sqlRequester = require('../../../target/mySqlRequester')
sqlDriver = require('../../../target/sqlDriver')
driverCache = require('../../../target/driverCache')

# Set up drivers
driverFns = {}

# Simple
# diamondsData = require('../../../data/diamonds.js')
# driverFns.simple = simpleDriver(diamondsData)

verbose = false

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
})

allowQuery = true
mySqlWrap = (query, callback) ->
  if not allowQuery
    console.log '---------------'
    console.log query
    console.log '---------------'
    throw new Error("query not allowed")

  mySql(query, callback)
  return

driverFns.mySqlCached = driverCache({
  driver: mySqlWrap
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Cache tests", ->
  @timeout(40 * 1000)

  describe "(sanity check) apply count", ->
    it "should produce the same result", testEquality {
      drivers: ['mySql', 'mySqlCached']
      query: [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

    # Top N Cache Test
  describe "split page; apply deleted, count; combine descending", ->
    it "should produce the same result", testEquality {
      drivers: ['mySql', 'mySqlCached']
      query: [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
      ]
    }

  describe "[cache tests on] topN", ->
    it "should produce the same result", -> {
      setUp: (callback) ->
        allowQuery = false
        callback()

      tearDown: (callback) ->
        allowQuery = true
        callback()

      "split page; apply deleted; combine descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }

      "split page; apply deleted, count; combine descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }
    }


  describe "different sorting works", ->
    it "should produce the same result", -> {
      "split page; apply deleted; combine descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }

      "split page; apply deleted; combine ascending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
        ]
      }

      "split page; apply deleted; combine Page, descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'descending' }, limit: 5 }
        ]
      }

      "split page; apply deleted; combine Page, ascending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'ascending' }, limit: 5 }
        ]
      }
    }


    # Cache Test
  describe "split time; apply count; apply added", ->
    it "should produce the same result", testEquality {
      drivers: ['mySql', 'mySqlCached']
      query: [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "[cache tests on] split time; apply count; apply added", ->
    it "should produce the same result", -> {
      setUp: (callback) ->
        allowQuery = false
        callback()

      tearDown: (callback) ->
        allowQuery = true
        callback()

      "split time; apply count": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      "split time; apply count; combine not by time": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
        ]
      }

      "split time; apply count; filter within another time filter": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 26, 12, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      "split time; apply count; limit": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
        ]
      }
    }

    # Cache Test 2
  describe "filter; split time; apply count; apply added", ->
    it "should produce the same result", testEquality {
      drivers: ['mySql', 'mySqlCached']
      query: [
        { operation: 'filter', type: 'and', filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        ]}
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "[cache tests on] filter; split time; apply count", ->
    it "should produce the same result", -> {
      setUp: (callback) ->
        allowQuery = false
        callback()

      tearDown: (callback) ->
        allowQuery = true
        callback()

      "filter; split time; apply count; apply added": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      "filter; split time; apply count; apply added; combine time descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }
    }

  describe "fillTree test", ->
    it "should produce the same result", -> { # TODO: Use better mechanism to test
      setUp: (callback) ->
        callback()

      tearDown: (callback) ->
        callback()

      "filter; split time; apply count; apply added": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      "filter; split time; apply count; apply added; combine time descending": testEquality {
        drivers: ['mySql', 'mySqlCached']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }
    }



