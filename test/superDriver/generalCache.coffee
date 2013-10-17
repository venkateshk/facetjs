chai = require("chai")
expect = chai.expect
utils = require('../utils')

sqlRequester = require('../../build/mySqlRequester')
sqlDriver = require('../../build/sqlDriver')
simpleDriver = require('../../build/simpleDriver')
generalCache = require('../../build/generalCache')

{FacetQuery} = require('../../build/query')

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
driverFns.diamondsCached = generalCache({
  driver: (request, callback) ->
    if checkEquality
      expect(request.query.valueOf()).to.deep.equal(expectedQuery)

    if not allowQuery
      throw new Error("query not allowed")

    diamonds(request, callback)
    return
  timeAttribute: 'time'
})

driverFns.wikipediaCached = generalCache({
  driver: (request, callback) ->
    if checkEquality
      expect(request.query.valueOf()).to.deep.equal(expectedQuery)

    if not allowQuery
      throw new Error("query not allowed")

    wikipedia(request, callback)
    return
  timeAttribute: 'time'
})

testEquality = utils.makeEqualityTest(driverFns)

describe "General cache", ->
  @timeout(40 * 1000)

  describe "emptyness checker", ->
    emptyDriver = (request, callback) ->
      callback(null, {})
      return

    emptyDriverCached = generalCache({
      driver: emptyDriver
    })

    it "should handle {}", (done) ->
      emptyDriverCached {
        query: new FacetQuery([
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        ])
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({})
        done()

  describe "zero checker", ->
    zeroDriver = (request, callback) ->
      callback(null, { prop: { Count: 0 } })
      return

    zeroDriverCached = generalCache({
      driver: zeroDriver
    })

    it "should handle zeroes", (done) ->
      zeroDriverCached {
        query: new FacetQuery([
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'apply', name: 'Count', aggregate: 'constant', value: '0' }
        ])
      }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({ prop: { Count: 0 } })
        done()

  describe "dateLightSaving checker", ->
    describe "with P1D granularity", ->
      it 'should work well when exiting daylightsaving time with P1D granularity', (done) ->
        dateLightSavingData = {
          prop: {},
          splits: [
            {prop: {bid_depth_adj: 0.013, timerange: ["2012-11-02T07:00:00.000Z", "2012-11-03T07:00:00.000Z"]}},
            {prop: {bid_depth_adj: 1.212, timerange: ["2012-11-03T07:00:00.000Z", "2012-11-04T07:00:00.000Z"]}},
            {prop: {bid_depth_adj: 1.188, timerange: ["2012-11-04T07:00:00.000Z", "2012-11-05T08:00:00.000Z"]}},
            {prop: {bid_depth_adj: 1.021, timerange: ["2012-11-05T08:00:00.000Z", "2012-11-06T08:00:00.000Z"]}},
            {prop: {bid_depth_adj: 0.980, timerange: ["2012-11-06T08:00:00.000Z", "2012-11-07T08:00:00.000Z"]}},
            {prop: {bid_depth_adj: 0.900, timerange: ["2012-11-07T08:00:00.000Z", "2012-11-08T08:00:00.000Z"]}}
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2012-11-02T07:00:00.000Z",
                "2012-11-08T08:00:00.000Z"
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
              "operation": "combine",
              "combine": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              }
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()

      it 'should work well when entering daylightsaving time with P1D granularity', (done) ->
        dateLightSavingData = {
          "prop": {},
          "splits": [
            {"prop": {"clicks": 2198708, "timerange": ["2013-03-08T08:00:00.000Z", "2013-03-09T08:00:00.000Z"]}},
            {"prop": {"clicks": 2326918, "timerange": ["2013-03-09T08:00:00.000Z", "2013-03-10T08:00:00.000Z"]}},
            {"prop": {"clicks": 2160294, "timerange": ["2013-03-10T08:00:00.000Z", "2013-03-11T07:00:00.000Z"]}},
            {"prop": {"clicks": 2005976, "timerange": ["2013-03-11T07:00:00.000Z", "2013-03-12T07:00:00.000Z"]}}
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2013-03-08T08:00:00.000Z",
                "2013-03-12T07:00:00.000Z"
              ],
              "operation": "filter"
            },
            {
              "bucket": "timePeriod",
              "name": "timerange",
              "attribute": "timestamp",
              "period": "P1D",
              "timezone": "America/Los_Angeles",
              "operation": "split"
            },
            {
              "name": "clicks",
              "aggregate": "sum",
              "attribute": "clicks",
              "operation": "apply"
            },
            {
              "method": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              },
              "operation": "combine"
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()


      it 'should work well when entering daylightsaving time with P1D granularity in UTC', (done) ->
        dateLightSavingData = {
          "prop": {},
          "splits": [
            {"prop": { "robot_ratio": 42.753, "timerange": ["2013-03-06T00:00:00.000Z","2013-03-07T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 53.123, "timerange": ["2013-03-07T00:00:00.000Z","2013-03-08T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 70.278, "timerange": ["2013-03-08T00:00:00.000Z","2013-03-09T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 77.486, "timerange": ["2013-03-09T00:00:00.000Z","2013-03-10T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 70.349, "timerange": ["2013-03-10T00:00:00.000Z","2013-03-11T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 72.075, "timerange": ["2013-03-11T00:00:00.000Z","2013-03-12T00:00:00.000Z"]}},
            {"prop": { "robot_ratio": 78.651, "timerange": ["2013-03-12T00:00:00.000Z","2013-03-13T00:00:00.000Z"]}}
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2013-03-06T00:00:00.000Z",
                "2013-03-13T00:00:00.000Z"
              ],
              "operation": "filter"
            },
            {
              "bucket": "timePeriod",
              "name": "timerange",
              "attribute": "timestamp",
              "period": "P1D",
              "timezone": "Etc/UTC",
              "operation": "split"
            },
            {
              "name": "robot_ratio",
              "arithmetic": "multiply",
              "operands": [
                {
                  "arithmetic": "divide",
                  "operands": [
                    {
                      "filter": {
                        "type": "is",
                        "attribute": "robot",
                        "value": "1"
                      },
                      "aggregate": "sum",
                      "attribute": "count"
                    },
                    {
                      "aggregate": "sum",
                      "attribute": "count"
                    }
                  ]
                },
                {
                  "aggregate": "constant",
                  "value": 100
                }
              ],
              "operation": "apply"
            },
            {
              "method": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              },
              "operation": "combine"
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()

      it 'should work well when exiting daylightsaving time with P1D granularity in UTC', (done) ->
        dateLightSavingData = {
          "prop": {},
          "splits": [
            {"prop": {"robot_ratio": 32.91625462537744,"timerange": ["2012-10-31T00:00:00.000Z","2012-11-01T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 32.86724075061008,"timerange": ["2012-11-01T00:00:00.000Z","2012-11-02T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 31.981365737636025,"timerange": ["2012-11-02T00:00:00.000Z","2012-11-03T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 31.25930447673803,"timerange": ["2012-11-03T00:00:00.000Z","2012-11-04T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 34.96826989128894,"timerange": ["2012-11-04T00:00:00.000Z","2012-11-05T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 34.62018157834334,"timerange": ["2012-11-05T00:00:00.000Z","2012-11-06T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 33.85529895170561,"timerange": ["2012-11-06T00:00:00.000Z","2012-11-07T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 34.45474777448071,"timerange": ["2012-11-07T00:00:00.000Z","2012-11-08T00:00:00.000Z"]}},
            {"prop": {"robot_ratio": 35.9824765755272,"timerange": ["2012-11-08T00:00:00.000Z","2012-11-09T00:00:00.000Z"]}}
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2012-10-31T00:00:00.000Z",
                "2012-11-09T00:00:00.000Z"
              ],
              "operation": "filter"
            },
            {
              "bucket": "timePeriod",
              "name": "timerange",
              "attribute": "timestamp",
              "period": "P1D",
              "timezone": "Etc/UTC",
              "operation": "split"
            },
            {
              "name": "robot_ratio",
              "arithmetic": "multiply",
              "operands": [
                {
                  "arithmetic": "divide",
                  "operands": [
                    {
                      "filter": {
                        "type": "is",
                        "attribute": "robot",
                        "value": "1"
                      },
                      "aggregate": "sum",
                      "attribute": "count"
                    },
                    {
                      "aggregate": "sum",
                      "attribute": "count"
                    }
                  ]
                },
                {
                  "aggregate": "constant",
                  "value": 100
                }
              ],
              "operation": "apply"
            },
            {
              "method": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              },
              "operation": "combine"
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()


    describe "with PT1H granularity", ->
      it 'should work well when entering daylightsaving time with PT1H granularity', (done) ->
        dateLightSavingData = {
          "prop": {},
          "splits": [
            { "prop": { "clicks": 75330, "timerange": [ "2013-03-09T07:00:00.000Z", "2013-03-09T08:00:00.000Z" ] } },
            { "prop": { "clicks": 72038, "timerange": [ "2013-03-09T08:00:00.000Z", "2013-03-09T09:00:00.000Z" ] } },
            { "prop": { "clicks": 69238, "timerange": [ "2013-03-09T09:00:00.000Z", "2013-03-09T10:00:00.000Z" ] } },
            { "prop": { "clicks": 66724, "timerange": [ "2013-03-09T10:00:00.000Z", "2013-03-09T11:00:00.000Z" ] } },
            { "prop": { "clicks": 70775, "timerange": [ "2013-03-09T11:00:00.000Z", "2013-03-09T12:00:00.000Z" ] } },
            { "prop": { "clicks": 83818, "timerange": [ "2013-03-09T12:00:00.000Z", "2013-03-09T13:00:00.000Z" ] } },
            { "prop": { "clicks": 101810, "timerange": [ "2013-03-09T13:00:00.000Z", "2013-03-09T14:00:00.000Z" ] } },
            { "prop": { "clicks": 107123, "timerange": [ "2013-03-09T14:00:00.000Z", "2013-03-09T15:00:00.000Z" ] } },
            { "prop": { "clicks": 114175, "timerange": [ "2013-03-09T15:00:00.000Z", "2013-03-09T16:00:00.000Z" ] } },
            { "prop": { "clicks": 114009, "timerange": [ "2013-03-09T16:00:00.000Z", "2013-03-09T17:00:00.000Z" ] } },
            { "prop": { "clicks": 113163, "timerange": [ "2013-03-09T17:00:00.000Z", "2013-03-09T18:00:00.000Z" ] } },
            { "prop": { "clicks": 117580, "timerange": [ "2013-03-09T18:00:00.000Z", "2013-03-09T19:00:00.000Z" ] } },
            { "prop": { "clicks": 113522, "timerange": [ "2013-03-09T19:00:00.000Z", "2013-03-09T20:00:00.000Z" ] } },
            { "prop": { "clicks": 107942, "timerange": [ "2013-03-09T20:00:00.000Z", "2013-03-09T21:00:00.000Z" ] } },
            { "prop": { "clicks": 107287, "timerange": [ "2013-03-09T21:00:00.000Z", "2013-03-09T22:00:00.000Z" ] } },
            { "prop": { "clicks": 105391, "timerange": [ "2013-03-09T22:00:00.000Z", "2013-03-09T23:00:00.000Z" ] } },
            { "prop": { "clicks": 111849, "timerange": [ "2013-03-09T23:00:00.000Z", "2013-03-10T00:00:00.000Z" ] } },
            { "prop": { "clicks": 117295, "timerange": [ "2013-03-10T00:00:00.000Z", "2013-03-10T01:00:00.000Z" ] } },
            { "prop": { "clicks": 113243, "timerange": [ "2013-03-10T01:00:00.000Z", "2013-03-10T02:00:00.000Z" ] } },
            { "prop": { "clicks": 108034, "timerange": [ "2013-03-10T02:00:00.000Z", "2013-03-10T03:00:00.000Z" ] } },
            { "prop": { "clicks": 99871, "timerange": [ "2013-03-10T03:00:00.000Z", "2013-03-10T04:00:00.000Z" ] } },
            { "prop": { "clicks": 88640, "timerange": [ "2013-03-10T04:00:00.000Z", "2013-03-10T05:00:00.000Z" ] } },
            { "prop": { "clicks": 84693, "timerange": [ "2013-03-10T05:00:00.000Z", "2013-03-10T06:00:00.000Z" ] } },
            { "prop": { "clicks": 69748, "timerange": [ "2013-03-10T06:00:00.000Z", "2013-03-10T07:00:00.000Z" ] } },
            { "prop": { "clicks": 68950, "timerange": [ "2013-03-10T07:00:00.000Z", "2013-03-10T08:00:00.000Z" ] } },
            { "prop": { "clicks": 70896, "timerange": [ "2013-03-10T08:00:00.000Z", "2013-03-10T09:00:00.000Z" ] } },
            { "prop": { "clicks": 69159, "timerange": [ "2013-03-10T09:00:00.000Z", "2013-03-10T10:00:00.000Z" ] } }
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2013-03-09T07:00:00.000Z",
                "2013-03-10T10:00:00.000Z"
              ],
              "operation": "filter"
            },
            {
              "bucket": "timePeriod",
              "name": "timerange",
              "attribute": "timestamp",
              "period": "PT1H",
              "timezone": "America/Los_Angeles",
              "operation": "split"
            },
            {
              "name": "clicks",
              "aggregate": "sum",
              "attribute": "clicks",
              "operation": "apply"
            },
            {
              "method": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              },
              "operation": "combine"
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()

      it 'should work well when exiting daylightsaving time with PT1H granularity', (done) ->
        dateLightSavingData = {
          "prop": {},
          "splits": [
            { "prop": { "clicks": 117295, "timerange": [ "2013-11-03T00:00:00.000Z", "2013-11-03T01:00:00.000Z" ] } },
            { "prop": { "clicks": 113243, "timerange": [ "2013-11-03T01:00:00.000Z", "2013-11-03T02:00:00.000Z" ] } },
            { "prop": { "clicks": 108034, "timerange": [ "2013-11-03T02:00:00.000Z", "2013-11-03T03:00:00.000Z" ] } },
            { "prop": { "clicks": 99871, "timerange": [ "2013-11-03T03:00:00.000Z", "2013-11-03T04:00:00.000Z" ] } },
            { "prop": { "clicks": 88640, "timerange": [ "2013-11-03T04:00:00.000Z", "2013-11-03T05:00:00.000Z" ] } },
            { "prop": { "clicks": 84693, "timerange": [ "2013-11-03T05:00:00.000Z", "2013-11-03T06:00:00.000Z" ] } },
            { "prop": { "clicks": 69748, "timerange": [ "2013-11-03T06:00:00.000Z", "2013-11-03T07:00:00.000Z" ] } },
            { "prop": { "clicks": 75330, "timerange": [ "2013-11-03T07:00:00.000Z", "2013-11-03T08:00:00.000Z" ] } },
            { "prop": { "clicks": 72038, "timerange": [ "2013-11-03T08:00:00.000Z", "2013-11-03T09:00:00.000Z" ] } },
            { "prop": { "clicks": 69238, "timerange": [ "2013-11-03T09:00:00.000Z", "2013-11-03T10:00:00.000Z" ] } },
            { "prop": { "clicks": 66724, "timerange": [ "2013-11-03T10:00:00.000Z", "2013-11-03T11:00:00.000Z" ] } },
            { "prop": { "clicks": 70775, "timerange": [ "2013-11-03T11:00:00.000Z", "2013-11-03T12:00:00.000Z" ] } }
          ]
        }

        dateLightSavingDriver = (request, callback) ->
          callback(null, dateLightSavingData)
          return

        dateLightSavingDriverCached = generalCache({
          driver: dateLightSavingDriver
        })

        dateLightSavingDriverCached {
          query: new FacetQuery([
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                "2013-11-03T00:00:00.000Z",
                "2013-11-03T12:00:00.000Z"
              ],
              "operation": "filter"
            },
            {
              "bucket": "timePeriod",
              "name": "timerange",
              "attribute": "timestamp",
              "period": "PT1H",
              "timezone": "America/Los_Angeles",
              "operation": "split"
            },
            {
              "name": "clicks",
              "aggregate": "sum",
              "attribute": "clicks",
              "operation": "apply"
            },
            {
              "method": "slice",
              "sort": {
                "compare": "natural",
                "prop": "timerange",
                "direction": "ascending"
              },
              "operation": "combine"
            }
          ])
        }, (err, result) ->
          expect(err).to.be.null
          expect(JSON.parse(JSON.stringify(result))).to.deep.equal(dateLightSavingData)
          done()


  describe "(sanity check) apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      query: [
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      ]
    }

  describe 'exclude filter Cache', ->
    setUpQuery = [
        { operation: "filter", type: "not", filter: { type: "in", attribute: "table", values: [ "61" ] } }
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]

    before (done) ->
      driverFns.diamondsCached({ query: new FacetQuery(setUpQuery) }, (err, result) ->
        throw err if err?
        done()
        return
      )

    after -> allowQuery = true

    it "split Color; apply Revenue; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      query: [
        { operation: "filter", type: "not", filter: { type: "in", attribute: "table", values: [ "61", "65" ] } }
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
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
      driverFns.diamondsCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before (done) ->
        driverFns.wikipediaCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
          throw err if err?
          allowQuery = false
          done()
          return
        )

      after -> allowQuery = true

      it "split time; apply count", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; filter within another time filter", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 26, 12, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; limit", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
        ]
      }


    describe "filtered on one thing", ->
      setUpQuery = [
        { operation: 'filter', type: 'and', filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
        ]}
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before (done) ->
        driverFns.wikipediaCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
        ]}
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before (done) ->
        driverFns.wikipediaCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          ]}
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }

    describe 'splits on time; combine on a metric', ->
      it "split time; apply count; combine count, descending (positive metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { name: "count", aggregate: "sum", attribute: "count", operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "count", direction: "descending" }, "limit": 5 }
        ]
      }

      it "split time; apply count; combine count, ascending (positive metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { name: "count", aggregate: "sum", attribute: "count", operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "count", direction: "ascending" }, "limit": 5 }
        ]
      }

      it "split time; apply deleted; combine deleted, descending (negative metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { name: "deleted", aggregate: "sum", attribute: "deleted", operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "descending" }, "limit": 5 }
        ]
      }

      it "split time; apply deleted; combine deleted, ascending (negative metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { name: "deleted", aggregate: "sum", attribute: "deleted", operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "ascending" }, "limit": 5 }
        ]
      }

      it "split time; apply count; combine count, descending, split page; apply count; combine count, descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { name: "count", aggregate: "sum", attribute: "count", operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "count", direction: "descending" }, "limit": 5 }
          { name: "page",attribute: "page",bucket: "identity",operation: "split" }
          { name: "count","aggregate": "sum",attribute: "count",operation: "apply" }
          { name: "deleted","aggregate": "sum",attribute: "deleted",operation: "apply" }
          { operation: "combine", combine: "slice", sort: { compare:"natural", prop: "count", direction: "descending" }, "limit": 5 }
        ]
      }

  describe "fillTree test", ->
    it "filter; split time; apply count; apply added", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      query: [
        { operation: 'filter', type: 'and', filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
        ]}
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
      ]
    }

  describe "splitCache fills filterCache as well", ->
    setUpQuery = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.wikipediaCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
        ]}
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

  describe "selected applies", ->
    setUpQuery = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before (done) ->
      driverFns.wikipediaCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
        throw err if err?
        checkEquality = true
        done()
        return
      )

    after -> checkEquality = false

    describe "filter; split time; apply count; apply added; combine time descending", ->
      before ->
        expectedQuery = [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))] }
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
      driverFns.diamondsCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
      driverFns.diamondsCached({query: new FacetQuery(setUpQuery)}, (err, result) ->
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
