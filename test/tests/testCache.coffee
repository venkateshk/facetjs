chai = require("chai")
expect = chai.expect
utils = require('../utils')

sqlRequester = require('../../target/mySqlRequester')
sqlDriver = require('../../target/sqlDriver')
simpleDriver = require('../../target/simpleDriver')
driverCache = require('../../target/driverCache')

# Set up drivers
driverFns = {}
allowQuery = true
checkEquality = false
expectedQuery = null

# Simple
diamondsData = require('../../data/diamonds.js')
driverFns.simple = simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

verbose = false
sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
})

# Cached Versions
driverFns.simpleCached = driverCache({
  driver: (query, callback) ->
    if checkEquality
      expect(query.query).to.deep.equal(expectedQuery)

    if not allowQuery
      console.log '\n---------------'
      console.log JSON.stringify(query, null, 2)
      console.log '---------------'
      throw new Error("query not allowed")

    simple(query, callback)
    return
  timeAttribute: 'time'
})

driverFns.mySqlCached = driverCache({
  driver: (query, callback) ->
    if checkEquality
      expect(query.query).to.deep.equal(expectedQuery)

    if not allowQuery
      console.log '\n---------------'
      console.log JSON.stringify(query, null, 2)
      console.log '---------------'
      throw new Error("query not allowed")

    mySql(query, callback)
    return
  timeAttribute: 'time'
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
      drivers: ['simpleCached', 'simple']
      query: [
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      ]
    }

  describe 'topN Cache', ->
    setUpQuery = [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]

    before (done) ->
      driverFns.simpleCached({ query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    it "split Color; apply Revenue; combine descending", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    it "split Color; apply Revenue, Cheapest; combine descending", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "different sorting", ->
      before -> allowQuery = true

      it "split Color; apply Revenue; combine Revenue, descending", testEquality {
          drivers: ['simpleCached', 'simple']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Revenue, ascending", testEquality {
          drivers: ['simpleCached', 'simple']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'ascending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Color, descending", testEquality {
          drivers: ['simpleCached', 'simple']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'descending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Color, ascending", testEquality {
          drivers: ['simpleCached', 'simple']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'ascending' }, limit: 5 }
          ]
        }


  describe "timeseries cache", ->
    describe "without filters", ->
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

      it "split time; apply count", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; combine not by time", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; filter within another time filter", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 26, 12, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; limit", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
          ]
        }


    describe "filtered on one thing", ->
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

      it "filter; split time; apply count; apply added", testEquality {
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

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
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


    describe "filtered on two things", ->
      setUpQuery = [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
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

      it "filter; split time; apply count; apply added", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            ]}
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
          drivers: ['mySqlCached', 'mySql']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            ]}
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
          ]
        }


  describe "fillTree test", ->
    it "filter; split time; apply count; apply added", testEquality {
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

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
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

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
        drivers: ['mySqlCached', 'mySql']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type:'within', attribute:'time', range: [ new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        ]
      }

  describe "selected applies", ->
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

  describe "multiple splits", ->
    setUpQuery = [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.simpleCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    it "filter; split time; apply count; split time; apply count; combine count descending", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

  describe "filtered splits cache", ->
    setUpQuery = [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
          prop: 'Color'
          type: 'in'
          values: ['E', 'I']
        }
      }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.simpleCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        done()
        return
      )

    describe "included filter", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['E']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "adding a new element outside filter", ->
      before ->
        checkEquality = true
        expectedQuery = [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['G']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]

      after ->
        checkEquality = false
        expectedQuery = null

      it "should have the same results for different drivers", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['I', 'G']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "only with a new element", ->
      before ->
        checkEquality = true
        expectedQuery = [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['H']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]

      after -> checkEquality = false

      it "should have the same results for different drivers", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['H']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "combine all filters", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['E', 'H', 'I', 'G']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    describe "same filter in a different order", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['simpleCached', 'simple']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut', bucketFilter: {
              prop: 'Color'
              type: 'in'
              values: ['I', 'E']
            }
          }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }
