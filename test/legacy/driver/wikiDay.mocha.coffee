{ expect } = require("chai")
utils = require('../../utils')

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{ druidRequester } = require('facetjs-druid-requester')
{ mySqlRequester } = require('facetjs-mysql-requester')

facet = require("../../../build/facet")
{ FacetFilter, simpleDriver, mySqlDriver, druidDriver } = facet.legacy

locations = require('../../locations')

# Set up drivers
driverFns = {}
verbose = false

# Simple
# diamondsData = require('../../build/data/diamonds.js')
# driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = mySqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = mySqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  host: locations.druid
})

druidPass = utils.wrapVerbose(druidPass, 'Druid') if verbose

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  forceInterval: true
  filter: FacetFilter.fromJS({
    type: 'within'
    attribute: 'time'
    range: [
      new Date("2013-02-26T00:00:00Z")
      new Date("2013-02-27T00:00:00Z")
    ]
  })
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Wikipedia day dataset", ->
  @timeout(40 * 1000)

  describe "apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "filter is; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "filter contains; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'filter', attribute: 'language', type: 'contains', value: 'e' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "filter match; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'filter', attribute: 'language', type: 'match', expression: 'e' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "apply arithmetic", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
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
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "split time (with warp); combine time", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', warp: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "split language; combine page", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Language', direction: 'ascending' }, limit: 20 }
      ]
    }

  describe "split time; apply count; combine ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
    }

  describe "split time; apply count; combine descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
      ]
    }

  describe "split time; apply count; sort Count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 4 }
      ]
    }

  describe "split time; apply count; sort Count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' }, limit: 4 }
      ]
    }

  # ToDo: Test timezone support

  describe "split page; apply count; sort count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
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
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Namespace', direction: 'ascending' } }
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
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Language', direction: 'ascending' } }
      ]
    }

  describe.skip "split page; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      #verbose: true
      query: [
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-26T03:00:00")
            new Date("2013-02-26T05:00:00")
          ]
        }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Page', direction: 'ascending' } }
      ]
    }

  describe "split language; apply count; sort count descending > split page; apply count; sort count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split language; apply count; sort count descending > split page (+filter); apply count; sort count descending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 10 }

        {
          operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page'
          segementFilter: {
            type: 'in'
            prop: 'Language'
            values: ['en', 'sv', 'poo']
          }
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Added', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split language; apply count; sort count descending > split page; apply count; sort count descending (filter bucket)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }

        {
          operation: 'split'
          name: 'Page'
          bucket: 'identity'
          attribute: 'page'
          segmentFilter: { type: 'in', prop: 'Language', values: ['en', 'fr'] }
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Added', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "split page; apply count; sort count ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
      ]
    }

  describe.skip "filter a && ~a; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
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
      drivers: ['druid', 'mySql']
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
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
    }

  describe "filter language=en; split page; apply count; sort deleted ascending", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Deleted', direction: 'ascending' }, limit: 5 }
      ]
    }

  describe "filter with nested ANDs", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: "filter",
          type: "and"
          filters: [
            {
              type: "within"
              attribute: "time"
              range: [
                new Date("2013-02-26T10:00:00")
                new Date("2013-02-26T15:00:00")
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
      drivers: ['druid', 'mySql']
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
      drivers: ['druid', 'mySql']
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
          operation: 'combine', method: 'slice'
          sort: { compare: 'natural', prop: 'Count R=0', direction: 'descending' }
          limit: 5
        }
      ]
    }

  describe.skip "split anonymous x robot; apply sum(count)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          "bucket": "tuple",
          "splits": [
            {
              "bucket": "identity",
              "name": "anonymous",
              "attribute": "anonymous"
            },
            {
              "bucket": "identity",
              "name": "robot",
              "attribute": "robot"
            }
          ],
          "operation": "split"
        },
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count",
          "operation": "apply"
        },
        {
          "method": "matrix",
          "sort": {
            "compare": "natural",
            "prop": "count",
            "direction": "descending"
          },
          "limits": [20, 20],
          "operation": "combine"
        }
      ]
    }

  describe "sort-by-delta", ->
    it "should work on a simple apply", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'dataset'
          name: 'robots'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '1'
          }
        }
        {
          operation: 'dataset'
          name: 'humans'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '0'
          }
        }
        {
          operation: 'filter'
          type: 'is'
          attribute: 'namespace'
          value: 'article'
        }
        {
          operation: 'split'
          name: 'Language'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'robots'
              bucket: 'identity'
              attribute: 'language'
            }
            {
              dataset: 'humans'
              bucket: 'identity'
              attribute: 'language'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
            { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'EditsDiff', compare: 'natural', direction: 'descending' }
          limit: 10
        }
      ]
    }

    it "should work on a derived apply", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'dataset'
          name: 'robots'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '1'
          }
        }
        {
          operation: 'dataset'
          name: 'humans'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '0'
          }
        }
        {
          operation: 'filter'
          type: 'is'
          attribute: 'namespace'
          value: 'article'
        }
        {
          operation: 'split'
          name: 'Language'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'robots'
              bucket: 'identity'
              attribute: 'language'
            }
            {
              dataset: 'humans'
              bucket: 'identity'
              attribute: 'language'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            {
              arithmetic: 'divide'
              operands: [
                { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
                { dataset: 'humans', aggregate: 'constant', value: 2 }
              ]
            }
            {
              arithmetic: 'divide'
              operands: [
                { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
                { dataset: 'robots', aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'EditsDiff', compare: 'natural', direction: 'descending' }
          limit: 10
        }
      ]
    }

    it "should work with a time split, positive warp (sort on time)", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'dataset'
          name: 'prevDate'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T00:00:00Z")
              new Date("2013-02-26T12:00:00Z")
            ]
          }
        }
        {
          operation: 'dataset'
          name: 'currentData'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T12:00:00Z")
              new Date("2013-02-27T00:00:00Z")
            ]
          }
        }
        {
          operation: 'split'
          name: 'TimeByHour'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'prevDate'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
              warp: 'PT12H'
            }
            {
              dataset: 'currentData'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'currentData'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'prevDate'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'TimeByHour', compare: 'natural', direction: 'ascending' }
        }
      ]
    }

    it "should work with a time split, negative warp (sort on time)", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'dataset'
          name: 'futureDate'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T12:00:00Z")
              new Date("2013-02-27T00:00:00Z")
            ]
          }
        }
        {
          operation: 'dataset'
          name: 'currentData'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T00:00:00Z")
              new Date("2013-02-26T12:00:00Z")
            ]
          }
        }
        {
          operation: 'split'
          name: 'TimeByHour'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'futureDate'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
              warp: 'PT12H'
              warpDirection: -1
            }
            {
              dataset: 'currentData'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'currentData'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'futureDate'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'TimeByHour', compare: 'natural', direction: 'ascending' }
        }
      ]
    }
