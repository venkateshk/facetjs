chai = require("chai")
expect = chai.expect
utils = require('../utils')

sqlRequester = require('../../build/mySqlRequester')
sqlDriver = require('../../build/sqlDriver')
simpleDriver = require('../../build/simpleDriver')
driverCache = require('../../build/driverCache')

# Set up drivers
driverFns = {}
allowQuery = true
checkEquality = false
expectedQuery = null

# Drivers
diamondsData = require('../../data/diamonds.js')
wikipediaData = require('../../data/wikipedia.js')
driverFns.diamonds = diamonds = simpleDriver(diamondsData)
driverFns.wikipedia = wikipedia = simpleDriver(wikipediaData)

# Cached Versions
driverFns.diamondsCached = driverCache({
  driver: (query, callback) ->
    if checkEquality
      expect(query.query).to.deep.equal(expectedQuery)

    if not allowQuery
      console.log '\n---------------'
      console.log JSON.stringify(query, null, 2)
      console.log '---------------'
      throw new Error("query not allowed")

    diamonds(query, callback)
    return
  timeAttribute: 'time'
})

driverFns.wikipediaCached = driverCache({
  driver: (query, callback) ->
    if checkEquality
      expect(query.query).to.deep.equal(expectedQuery)

    if not allowQuery
      console.log '\n---------------'
      console.log JSON.stringify(query, null, 2)
      console.log '---------------'
      throw new Error("query not allowed")

    wikipedia(query, callback)
    return
  timeAttribute: 'time'
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Cache", ->
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'apply', name: 'Count', aggregate: 'constant', value: '0' }
        ]
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({ prop: { Count: 0 } })
        done()

  describe "dateLightSaving checker", ->
    dateLightSavingData = {
      prop: {},
      splits: [
        {
          prop: {
            bid_depth_adj: 1.2466818548667042,
            avg_latency: 0.013069229864317534,
            uniques: 0,
            timerange: [
              new Date("2012-11-02T07:00:00.000Z"),
              new Date("2012-11-03T07:00:00.000Z")
            ]
          }
        },
        {
          prop: {
            avg_latency: 0.013148476570233917,
            bid_depth_adj: 1.212463873557697,
            uniques: 0,
            timerange: [
              new Date("2012-11-03T07:00:00.000Z"),
              new Date("2012-11-04T07:00:00.000Z")
            ]
          }
        },
        {
          prop: {
            avg_latency: 0.01260590998216896,
            bid_depth_adj: 1.1883019697926953,
            uniques: 0,
            timerange: [
              new Date("2012-11-04T07:00:00.000Z"),
              new Date("2012-11-05T08:00:00.000Z")
            ]
          }
        },
        {
          prop: {
            avg_latency: 0.018073973399774193,
            bid_depth_adj: 1.0214784473305347,
            uniques: 0,
            timerange: [
              new Date("2012-11-05T08:00:00.000Z"),
              new Date("2012-11-06T08:00:00.000Z")
            ]
          }
        },
        {
          prop: {
            avg_latency: 0.017976455114079474,
            bid_depth_adj: 0.9800624388099162,
            uniques: 0,
            timerange: [
              new Date("2012-11-06T08:00:00.000Z"),
              new Date("2012-11-07T08:00:00.000Z")
            ]
          }
        },
        {
          prop: {
            avg_latency: 0.016441307868576543,
            bid_depth_adj: 0.9009174579839136,
            uniques: 0,
            timerange: [
              new Date("2012-11-07T08:00:00.000Z"),
              new Date("2012-11-08T08:00:00.000Z")
            ]
          }
        }
      ]
    }

    dateLightSavingDriver = (request, callback) ->
      callback(null, dateLightSavingData)
      return

    dateLightSavingDriverCached = driverCache({
      driver: dateLightSavingDriver
    })

    it "should handle preset data", (done) ->
      dateLightSavingDriverCached {
        query: [
          {
            "type": "within",
            "attribute": "timestamp",
            "range": [
              new Date("2012-11-02T07:00:00.000Z"),
              new Date("2012-11-08T08:00:00.000Z")
            ],
            "operation": "filter"
          },
          {
            "name": "timerange",
            "attribute": "timestamp",
            "bucket": "timePeriod",
            "period": "P1D",
            "timezone": "America/Los_Angeles",
            "operation": "split"
          },
          {
            "name": "bid_depth_adj",
            "arithmetic": "divide",
            "operands": [
              {
                "attribute": "bid_depth",
                "aggregate": "sum"
              },
              {
                "attribute": "impressions",
                "aggregate": "sum"
              }
            ],
            "operation": "apply"
          },
          {
            "name": "avg_latency",
            "arithmetic": "divide",
            "operands": [
              {
                "attribute": "latency",
                "aggregate": "sum"
              },
              {
                "attribute": "impressions",
                "aggregate": "sum"
              }
            ],
            "operation": "apply"
          },
          {
            "name": "uniques",
            "aggregate": "uniqueCount",
            "attribute": "unique_dpid",
            "operation": "apply"
          },
          {
            "operation": "combine",
            "combine": "slice",
            "sort": {
              "compare": "natural",
              "prop": "timerange",
              "direction": "ascending"
            }
          }
        ]
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal(dateLightSavingData)
        done()

  describe "(sanity check) apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['diamondsCached', 'diamonds']
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
      driverFns.diamondsCached({ query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    it "split Color; apply Revenue; combine descending", testEquality {
        drivers: ['diamondsCached', 'diamonds']
        query: [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      }

    it "split Color; apply Revenue, Cheapest; combine descending", testEquality {
        drivers: ['diamondsCached', 'diamonds']
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
          drivers: ['diamondsCached', 'diamonds']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Revenue, ascending", testEquality {
          drivers: ['diamondsCached', 'diamonds']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'ascending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Color, descending", testEquality {
          drivers: ['diamondsCached', 'diamonds']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'descending' }, limit: 5 }
          ]
        }

      it "split Color; apply Revenue; combine Color, ascending", testEquality {
          drivers: ['diamondsCached', 'diamonds']
          query: [
            { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
            { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'ascending' }, limit: 5 }
          ]
        }


  describe "timeseries cache", ->
    describe "without filters", ->
      setUpQuery = [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]

      before (done) ->
        driverFns.wikipediaCached({query: setUpQuery}, (err, result) ->
          throw err if err?
          allowQuery = false
          done()
          return
        )

      after -> allowQuery = true

      it "split time; apply count", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; combine not by time", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; filter within another time filter", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 26, 12, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "split time; apply count; limit", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
          ]
        }


    describe "filtered on one thing", ->
      setUpQuery = [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]

      before (done) ->
        driverFns.wikipediaCached({query: setUpQuery}, (err, result) ->
          throw err if err?
          allowQuery = false
          done()
          return
        )

      after -> allowQuery = true

      it "filter; split time; apply count; apply added", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            ]}
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
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
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]

      before (done) ->
        driverFns.wikipediaCached({query: setUpQuery}, (err, result) ->
          throw err if err?
          allowQuery = false
          done()
          return
        )

      after -> allowQuery = true

      it "filter; split time; apply count; apply added", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            ]}
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        }

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
          drivers: ['wikipediaCached', 'wikipedia']
          query: [
            { operation: 'filter', type: 'and', filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
            ]}
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
          ]
        }


  describe "fillTree test", ->
    it "filter; split time; apply count; apply added", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }

  describe "splitCache fills filterCache as well", ->
    setUpQuery = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.wikipediaCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'and', filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          ]}
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        ]
      }

  describe "selected applies", ->
    setUpQuery = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.wikipediaCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        checkEquality = true
        done()
        return
      )

    after -> checkEquality = false

    describe "filter; split time; apply count; apply added; combine time descending", ->
      before ->
        expectedQuery = [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]

      after ->
        expectedQuery = null

      it "should have the same results for different drivers", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
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
      driverFns.diamondsCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        allowQuery = false
        done()
        return
      )

    after -> allowQuery = true

    it "filter; split time; apply count; split time; apply count; combine count descending", testEquality {
        drivers: ['diamondsCached', 'diamonds']
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
      driverFns.diamondsCached({query: setUpQuery}, (err, result) ->
        throw err if err?
        done()
        return
      )

    describe "included filter", ->
      before -> allowQuery = false
      after -> allowQuery = true

      it "should have the same results for different drivers", testEquality {
        drivers: ['diamondsCached', 'diamonds']
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
        drivers: ['diamondsCached', 'diamonds']
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
        drivers: ['diamondsCached', 'diamonds']
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
        drivers: ['diamondsCached', 'diamonds']
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
        drivers: ['diamondsCached', 'diamonds']
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
