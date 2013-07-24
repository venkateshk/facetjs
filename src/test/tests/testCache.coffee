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
checkEquality = false
expectedQuery = null
mySqlWrap = (query, callback) ->
  if checkEquality
    expect(query).to.deep.equal(expectedQuery)

  if not allowQuery
    console.log '\n---------------'
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

  describe "emptyness checker", ->
    emptyDriver = (request, callback) ->
      callback(null, {})
      return

    emptyDriverCached = driverCache({
      driver: emptyDriver
    })

    it "should handle {}", (done) ->
      emptyDriverCached {
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        ]
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({})
        done()

  describe "zero checker", ->
    zeroDriver = (request, callback) ->
      callback(null, { prop: { Count: 0 } })
      return

    zeroDriverCached = driverCache({
      driver: zeroDriver
    })

    it "should handle zeroes", (done) ->
      zeroDriverCached {
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'apply', name: 'Count', aggregate: 'constant', value: '0' }
        ]
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({ prop: { Count: 0 } })
        done()

  describe "(sanity check) apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySqlCached', 'mySql']
      query: [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe 'topN Cache', ->
    setUpQuery = [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
      ]

    before (done) ->
      driverFns.mySqlCached({ query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    describe "split page; apply deleted; combine descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "split page; apply deleted, count; combine descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }


  describe "different sorting works", ->
    describe "split page; apply deleted; combine descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "split page; apply deleted; combine ascending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
        ]
      }

    describe "split page; apply deleted; combine Page, descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "split page; apply deleted; combine Page, ascending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'ascending' }, limit: 5 }
        ]
      }


  # Cache Test
  describe "split time; apply count; apply added", ->
    setUpQuery = [
        { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    describe "split time; apply count", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

    describe "split time; apply count; combine not by time", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
        ]
      }

    describe "split time; apply count; filter within another time filter", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 26, 12, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

    describe "split time; apply count; limit", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
        ]
      }


    # Cache Test 2
  describe "filter; split time; apply count; apply added", ->
    setUpQuery = [
        { operation: 'filter', type: 'and', filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        ]}
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    describe "filter; split time; apply count; apply added", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
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

    describe "filter; split time; apply count; apply added; combine time descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
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


  describe "fillTree test", ->
    describe "filter; split time; apply count; apply added", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
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

    describe "filter; split time; apply count; apply added; combine time descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
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

  describe "splitCache fills filterCache as well", ->
    setUpQuery = [
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    describe "filter; split time; apply count; apply added; combine time descending", ->
      testQuery = [
        { operation: 'filter', type: 'and', filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
        ]}
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: testQuery
      }

  describe "doesn't query for known data", ->
    setUpQuery = [
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        checkEquality = true
        done()
        return
      )

    after -> checkEquality = false

    describe "filter; split time; apply count; apply added; combine time descending", ->
      before ->
        expectedQuery = [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]

      after ->
        expectedQuery = null

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

  describe "handles multiple splits", ->
    setUpQuery = [
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
      { operation: 'split', name: 'Namespace', bucket: 'identity', attribute: 'namespace' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    describe "filter; split time; apply count; split time; apply count; combine count descending", ->
      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Namespace', bucket: 'identity', attribute: 'namespace' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

  describe "handles filtered splits", ->
    setUpQuery = [
      { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
      {
        operation: 'split'
        name: 'Namespace'
        bucket: 'identity'
        attribute: 'namespace',
        bucketFilter: {
          prop: 'Language'
          type: 'in'
          values: ['en', 'de']
        }
      }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.mySqlCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        done()
        return
      )

    describe "included filter", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['en']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "adding a new element outside filter", ->
      before ->
        checkEquality = true
        expectedQuery = [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['fr']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]

      after ->
        checkEquality = false
        expectedQuery = null

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['en', 'fr']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "only with a new element", ->
      before ->
        checkEquality = true
        expectedQuery = [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['it']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]

      after -> checkEquality = false

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['it']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "combine all filters", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['en','de','fr','it']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "same filter in a different order", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
          {
            operation: 'split'
            name: 'Namespace'
            bucket: 'identity'
            attribute: 'namespace',
            bucketFilter: {
              prop: 'Language'
              type: 'in'
              values: ['fr','en']
            }
          }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      }
