chai = require("chai")
expect = chai.expect
utils = require('../utils')

druidRequester = require('../../target/druidRequester')
sqlRequester = require('../../target/mySqlRequester')

simpleDriver = require('../../target/simpleDriver')
sqlDriver = require('../../target/sqlDriver')
druidDriver = require('../../target/druidDriver')

# Set up drivers
driverFns = {}
verbose = false

# Simple
# diamondsData = require('../../target/data/diamonds.js')
# driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  host: '10.60.134.138'
  port: 8080
})

druidPass = utils.wrapVerbose(druidPass, 'Druid') if verbose

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  forceInterval: true
  filter: {
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
    ]
  }
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Wikipedia dataset test", ->
  @timeout(40 * 1000)

  describe "apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "filter; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "apply arithmetic", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        {
          operation: 'apply'
          name: 'Added + Deleted'
          arithmetic: 'add'
          operands: [
            { aggregate: 'sum', attribute: 'added' }
            { aggregate: 'sum', attribute: 'deleted' }
          ]
        }
        {
          operation: 'apply'
          name: 'Added - Deleted'
          arithmetic: 'subtract'
          operands: [
            { aggregate: 'sum', attribute: 'added' }
            { aggregate: 'sum', attribute: 'deleted' }
          ]
        }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "split time; combine time", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe.skip "split page; combine page", ->  # The sorting here still does not match - ask FJ
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'ascending' }, limit: 20 }
      ]
    }

  describe "split time; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "split time; apply count; sort Count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split time; apply count; sort Count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' }, limit: 3 }
      ]
    }

  # ToDo: Test timezone support

  describe "split page; apply count; sort count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
      ]
    }


  describe.skip "split namespace; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      #verbose: true
      query: [
        { operation: 'split', name: 'Namespace', bucket: 'identity', attribute: 'namespace' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Namespace', direction: 'ascending' } }
      ]
    }

  describe.skip "split language; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      #verbose: true
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Language', direction: 'ascending' } }
      ]
    }

  describe.skip "split page; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      #verbose: true
      query: [
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
            new Date(Date.UTC(2013, 2-1, 27, 1, 0, 0))
          ]
        }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'ascending' } }
      ]
    }

  describe "split language; apply count; sort count descending > split page; apply count; sort count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split language; apply count; sort count descending > split page; apply count; sort count descending (filter bucket)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }

        {
          operation: 'split'
          name: 'Page'
          bucket: 'identity'
          attribute: 'page'
          bucketFilter: { type: 'in', prop: 'Language', values: ['en', 'fr'] }
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split page; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
      ]
    }

  describe.skip "filter a && ~a; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { attribute: 'language', type: 'is', value: 'en' }
            { type: 'not', filter: { attribute: 'language', type: 'is', value: 'en' } }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ]
    }

  describe.skip "filter a && ~a; split page; apply count; sort count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { attribute: 'language', type: 'is', value: 'en' }
            { type: 'not', filter: { attribute: 'language', type: 'is', value: 'en' } }
          ]
        }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "filter language=en; split page; apply count; sort deleted ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
      ]
    }

  describe "filter with nested ANDs", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        {
          operation: "filter",
          type: "and"
          filters: [
            {
              type: "within"
              attribute: "time"
              range: [
                new Date(Date.UTC(2013, 2-1, 26, 10, 0, 0))
                new Date(Date.UTC(2013, 2-1, 27, 15, 0, 0))
              ]
            }
            {
              type: "and",
              filters: [
                { type: "is", attribute: "robot", value: "0" }
                { type: "is", attribute: "namespace", value: "article" }
                { type: "is", attribute: "language", value: "en" }
              ]
            }
          ]
        },
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      ]
    }

  # Should work once druid with advanced JS aggregate is deployed
  describe "apply sum(count, robot=0), sum(added, robot=1)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        {
          operation: "apply"
          name: "Count R=0"
          aggregate: "sum", attribute: "count"
          filter: { type: 'is', attribute: "robot", value: "0" }
        }
        {
          operation: "apply"
          name: "Added R=1"
          aggregate: "sum", attribute: "added"
          filter: { type: 'is', attribute: "robot", value: "1" }
        }
        {
          operation: "apply"
          name: "Min Added R=1"
          aggregate: "min", attribute: "added"
          filter: { type: 'is', attribute: "robot", value: "1" }
        }
        {
          operation: "apply"
          name: "Max Added R=1"
          aggregate: "max", attribute: "added"
          filter: { type: 'is', attribute: "robot", value: "1" }
        }
        {
          operation: "apply"
          name: "CountComplexFilter"
          aggregate: "sum", attribute: "count"
          filter: {
            type: 'and'
            filters: [
              { type: 'is', attribute: "robot", value: "1" }
              { type: 'in', attribute: "language", values: ["en", "fr"] }
            ]
          }
        }
      ]
    }

  describe "split page; apply sum(count, robot=0), sum(added, robot=1)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['mySql', 'druid']
      query: [
        {
          operation: "split"
          name: 'Page', bucket: 'identity', attribute: 'page'
        }
        {
          operation: "apply"
          name: "Count R=0"
          aggregate: "sum", attribute: "count"
          filter: { type: 'is', attribute: "robot", value: "0" }
        }
        {
          operation: "apply"
          name: "Added R=1"
          aggregate: "sum", attribute: "added"
          filter: { type: 'is', attribute: "robot", value: "1" }
        }
        {
          operation: 'combine', combine: 'slice'
          sort: { compare: 'natural', prop: 'Count R=0', direction: 'descending' }
          limit: 5
        }
      ]
    }
