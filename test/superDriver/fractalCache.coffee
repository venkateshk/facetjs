"use strict"

{ expect } = require("chai")

utils = require('../utils')

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{isInstanceOf} = require('../../src/util')
sqlRequester = require('../../src/requester/mySqlRequester')
sqlDriver = require('../../src/driver/sqlDriver')
simpleDriver = require('../../src/driver/simpleDriver')
SegmentTree = require('../../src/driver/segmentTree')
fractalCache = require('../../src/superDriver/fractalCache')

{FacetQuery} = require('../../src/query')

# Set up drivers
driverFns = {}
expectedQuery = false

# Drivers
diamondsData = require('../../data/diamonds.js')
wikipediaData = require('../../data/wikipedia.js')
driverFns.diamonds = diamonds = simpleDriver(diamondsData)
driverFns.wikipedia = wikipedia = simpleDriver(wikipediaData)

# Cached Versions
firstForbindenQuery = true
wrapDriver = (driver) -> (request, callback) ->
  if isInstanceOf(expectedQuery, FacetQuery)
    expect(request.query.valueOf()).to.deep.equal(expectedQuery.valueOf())

  if expectedQuery is false
    if firstForbindenQuery
      firstForbindenQuery = false
      console.log('Forbidden:', request.query.valueOf())
    throw new Error("query not allowed")

  driver(request, callback)
  return

currentTimeOverride = null
fractalCache.currentTime = ->
  return currentTimeOverride if currentTimeOverride
  return Date.now()

driverFns.diamondsCached = fractalCache({
  driver: wrapDriver(diamonds)
  debug: true
})

driverFns.wikipediaCached = fractalCache({
  driver: wrapDriver(wikipedia)
  debug: true
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Fractal cache", ->
  @timeout(40 * 1000)

  describe.skip "errors", ->
    it "complains when there is no query", ->
      expect(->
        driverFns.wikipediaCached({})
      ).to.throw('lol')

  describe.skip "emptyness checker", ->
    emptyDriver = (request, callback) ->
      callback(null, {})
      return

    emptyDriverCached = fractalCache({
      driver: emptyDriver
    })

    it "should handle {}", (done) ->
      emptyDriverCached {
        query: new FacetQuery([
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        ])
      }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({})
        done()


  describe "zero checker", ->
    zeroDriver = (request, callback) ->
      callback(null, { prop: { Count: 0 } })
      return

    zeroDriverCached = fractalCache({
      driver: zeroDriver
    })

    it "should handle zeroes", (done) ->
      zeroDriverCached {
        query: new FacetQuery([
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'apply', name: 'Count', aggregate: 'constant', value: 0 }
        ])
      }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({ prop: { Count: 0 } })
        done()


  describe "No split", ->
    setUpQuery = new FacetQuery [
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      {
        operation: 'apply'
        name: 'MinPlusMaxCarat'
        arithmetic: 'add'
        operands: [
          {
            aggregate: 'min'
            attribute: 'carat'
          }
          {
            aggregate: 'max'
            attribute: 'carat'
          }
        ]
      }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      query: setUpQuery
      before: ->
        expectedQuery = new FacetQuery [
          {
            name: "c_S1_MinPlusMaxCarat",
            aggregate: "min",
            attribute: "carat",
            operation: "apply"
          },
          {
            name: "Cheapest",
            aggregate: "min",
            attribute: "price",
            operation: "apply"
          },
          {
            name: "c_S2_MinPlusMaxCarat",
            aggregate: "max",
            attribute: "carat",
            operation: "apply"
          },
          {
            name: "Revenue",
            aggregate: "sum",
            attribute: "price",
            operation: "apply"
          }
        ]
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "apply Cheapest, Revenue", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      ]
    }

    it "apply Revenue", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      ]
    }

    it "apply Revenue, Expensive", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          {
            name: 'Expensive',
            aggregate: 'max',
            attribute: 'price',
            operation: 'apply'
          }
        ]
      query: [
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'apply', name: 'Expensive', aggregate: 'max', attribute: 'price' }
      ]
    }


  describe "No split (multi-dataset)", ->
    setUpQuery = new FacetQuery [
      {
        operation: 'dataset'
        name: 'ideal-cut'
        source: 'base'
        filter: {
          dataset: 'ideal-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Ideal'
        }
      }
      {
        operation: 'dataset'
        name: 'good-cut'
        source: 'base'
        filter: {
          dataset: 'good-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
      }
      {
        operation: 'apply'
        name: 'PriceDiff'
        arithmetic: 'subtract'
        operands: [
          {
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
      }
      {
        operation: 'apply'
        name: 'AvgIdealPrice'
        dataset: 'ideal-cut'
        aggregate: 'average'
        attribute: 'price'
      }
      {
        operation: 'apply'
        name: 'AvgGoodPrice'
        dataset: 'good-cut'
        aggregate: 'average'
        attribute: 'price'
      }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      query: setUpQuery
      before: ->
        expectedQuery = new FacetQuery [
          {
            operation: 'dataset'
            name: 'ideal-cut'
            source: 'base'
            filter: {
              dataset: 'ideal-cut'
              type: 'is'
              attribute: 'cut'
              value: 'Ideal'
            }
          }
          {
            operation: 'dataset'
            name: 'good-cut'
            source: 'base'
            filter: {
              dataset: 'good-cut'
              type: 'is'
              attribute: 'cut'
              value: 'Good'
            }
          }
          {
            operation: 'apply'
            name: 'AvgGoodPrice'
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            operation: 'apply'
            name: 'AvgIdealPrice'
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "apply PriceDiff", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'dataset'
          name: 'good-cut'
          source: 'base'
          filter: {
            dataset: 'good-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Good'
          }
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
      ]
    }

    it "apply AvgPrice", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'apply'
          name: 'AvgPrice'
          aggregate: 'average'
          attribute: 'price'
          dataset: 'ideal-cut'
        }
      ]
    }


  describe 'Identity split cache (incomplete)', ->
    setUpQuery = new FacetQuery [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "split Color; apply Revenue; apply Expensive; combine Revenue, descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          {
            operation: "filter"
            type: "in"
            attribute: "color"
            values: ["E", "F", "G", "H", "I"]
          }
          {
            bucket: 'identity',
            name: 'Color',
            attribute: 'color',
            operation: 'split'
          }
          {
            name: 'Expensive',
            aggregate: 'max',
            attribute: 'price',
            operation: 'apply'
          }
          {
            name: 'Revenue',
            aggregate: 'sum',
            attribute: 'price',
            operation: 'apply'
          }
          {
            method: 'slice',
            sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' },
            limit: 5,
            operation: 'combine'
          }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'apply', name: 'Expensive', aggregate: 'max', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine descending limit 3", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 3 }
      ]
    }

    it "filter color=G; apply Rev", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'filter', type: 'is', attribute: 'color', value: 'G' }
        { operation: 'apply', name: 'Rev', aggregate: 'sum', attribute: 'price' }
      ]
    }

    it "split Color; apply Revenue; combine Revenue, ascending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          {
            bucket: 'identity',
            name: 'Color',
            attribute: 'color',
            operation: 'split'
          }
          {
            name: 'Revenue',
            aggregate: 'sum',
            attribute: 'price',
            operation: 'apply'
          }
          {
            method: 'slice',
            sort: { compare: 'natural', prop: 'Revenue', direction: 'ascending' },
            limit: 5,
            operation: 'combine'
          }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'ascending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Color, descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = [
          {
            bucket: 'identity',
            name: 'Color',
            attribute: 'color',
            operation: 'split'
          },
          {
            name: 'Revenue',
            aggregate: 'sum',
            attribute: 'price',
            operation: 'apply'
          },
          {
            method: 'slice',
            sort: { compare: 'natural', prop: 'Color', direction: 'descending' },
            limit: 5,
            operation: 'combine'
          }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Color, ascending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = [
          {
            bucket: 'identity',
            name: 'Color',
            attribute: 'color',
            operation: 'split'
          },
          {
            name: 'Revenue',
            aggregate: 'sum',
            attribute: 'price',
            operation: 'apply'
          },
          {
            method: 'slice',
            sort: { compare: 'natural', prop: 'Color', direction: 'ascending' },
            limit: 5,
            operation: 'combine'
          }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'ascending' }, limit: 5 }
      ]
    }


  describe 'Identity split cache (complete)', ->
    setUpQuery = new FacetQuery [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 8 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "split Color; apply Revenue; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue, Cheapest; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Revenue, descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Revenue, ascending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'ascending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Color, descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'descending' }, limit: 5 }
      ]
    }

    it "split Color; apply Revenue; combine Color, ascending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'ascending' }, limit: 5 }
      ]
    }

    it "filter color=D; split Color; apply Revenue; combine Color, descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'filter', type: 'is', attribute: 'color', value: 'D' }
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Color', direction: 'descending' }, limit: 5 }
      ]
    }


  describe 'Identity split cache (filtered / incomplete)', ->
    setUpQuery = new FacetQuery [
      { operation: 'filter', type: 'is', attribute: 'color', value: 'H' }
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "handles unfilter", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      query: new FacetQuery [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }


  describe 'Identity split cache sort-single-dataset (complete)', ->
    setUpQuery = new FacetQuery [
      {
        operation: 'dataset'
        name: 'ideal-cut'
        source: 'base'
        filter: {
          dataset: 'ideal-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Ideal'
        }
      }
      {
        operation: 'dataset'
        name: 'good-cut'
        source: 'base'
        filter: {
          dataset: 'good-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
      }
      {
        operation: 'split'
        name: 'Clarity'
        bucket: 'parallel'
        splits: [
          {
            dataset: 'ideal-cut'
            bucket: 'identity'
            attribute: 'clarity'
          }
          {
            dataset: 'good-cut'
            bucket: 'identity'
            attribute: 'clarity'
          }
        ]
      }
      {
        operation: 'apply'
        name: 'PriceDiff'
        arithmetic: 'subtract'
        operands: [
          {
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
      }
      {
        operation: 'apply'
        name: 'AvgIdealPrice'
        dataset: 'ideal-cut'
        aggregate: 'average'
        attribute: 'price'
      }
      {
        operation: 'apply'
        name: 'AvgGoodPrice'
        dataset: 'good-cut'
        aggregate: 'average'
        attribute: 'price'
      }
      {
        operation: 'combine'
        method: 'slice'
        sort: { prop: 'AvgIdealPrice', compare: 'natural', direction: 'descending' }
        limit: 20
      }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          {
            operation: 'dataset'
            name: 'ideal-cut'
            source: 'base'
            filter: {
              dataset: 'ideal-cut'
              type: 'is'
              attribute: 'cut'
              value: 'Ideal'
            }
          }
          {
            operation: 'dataset'
            name: 'good-cut'
            source: 'base'
            filter: {
              dataset: 'good-cut'
              type: 'is'
              attribute: 'cut'
              value: 'Good'
            }
          }
          {
            operation: 'split'
            name: 'Clarity'
            bucket: 'parallel'
            splits: [
              {
                dataset: 'ideal-cut'
                bucket: 'identity'
                attribute: 'clarity'
              }
              {
                dataset: 'good-cut'
                bucket: 'identity'
                attribute: 'clarity'
              }
            ]
          }
          {
            operation: 'apply'
            name: 'AvgIdealPrice'
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            operation: 'apply'
            name: 'AvgGoodPrice'
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            operation: 'combine'
            method: 'slice'
            sort: { prop: 'AvgIdealPrice', compare: 'natural', direction: 'descending' }
            limit: 20
          }
        ]
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "split parallel Cut; apply AvgIdealCut, AvgGoodCut; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'identity'
          attribute: 'clarity'
          dataset: 'ideal-cut'
        }
        {
          operation: 'apply'
          name: 'AvgIdealPrice'
          aggregate: 'average'
          attribute: 'price'
          dataset: 'ideal-cut'
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'AvgIdealPrice', compare: 'natural', direction: 'ascending' }
          limit: 20
        }
      ]
    }


  describe 'Identity split cache sort-multi-dataset (complete)', ->
    setUpQuery = new FacetQuery [
      {
        operation: 'dataset'
        name: 'ideal-cut'
        source: 'base'
        filter: {
          dataset: 'ideal-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Ideal'
        }
      }
      {
        operation: 'dataset'
        name: 'good-cut'
        source: 'base'
        filter: {
          dataset: 'good-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
      }
      {
        operation: 'split'
        name: 'Clarity'
        bucket: 'parallel'
        splits: [
          {
            dataset: 'ideal-cut'
            bucket: 'identity'
            attribute: 'clarity'
          }
          {
            dataset: 'good-cut'
            bucket: 'identity'
            attribute: 'clarity'
          }
        ]
      }
      {
        operation: 'apply'
        name: 'AvgIdealPrice'
        dataset: 'ideal-cut'
        aggregate: 'average'
        attribute: 'price'
      }
      {
        operation: 'apply'
        name: 'AvgGoodPrice'
        dataset: 'good-cut'
        aggregate: 'average'
        attribute: 'price'
      }
      {
        operation: 'apply'
        name: 'PriceDiff'
        arithmetic: 'subtract'
        operands: [
          {
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
      }
      {
        operation: 'combine'
        method: 'slice'
        sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
        limit: 20
      }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "split parallel Cut; apply AvgIdealCut, AvgGoodCut; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'dataset'
          name: 'good-cut'
          source: 'base'
          filter: {
            dataset: 'good-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Good'
          }
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'ideal-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
            {
              dataset: 'good-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'AvgIdealPrice'
          dataset: 'ideal-cut'
          aggregate: 'average'
          attribute: 'price'
        }
        {
          operation: 'apply'
          name: 'AvgGoodPrice'
          dataset: 'good-cut'
          aggregate: 'average'
          attribute: 'price'
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
          limit: 20
        }
      ]
    }

    it "split parallel Cut; apply AvgIdealCut, AvgGoodCut; combine ascending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'dataset'
          name: 'good-cut'
          source: 'base'
          filter: {
            dataset: 'good-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Good'
          }
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'ideal-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
            {
              dataset: 'good-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'AvgIdealPrice'
          dataset: 'ideal-cut'
          aggregate: 'average'
          attribute: 'price'
        }
        {
          operation: 'apply'
          name: 'AvgGoodPrice'
          dataset: 'good-cut'
          aggregate: 'average'
          attribute: 'price'
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'PriceDiff', compare: 'natural', direction: 'ascending' }
          limit: 10
        }
      ]
    }


  describe 'works with exclude filters', ->
    setUpQuery = new FacetQuery [
      { operation: "filter", type: "not", filter: { type: "is", attribute: "table", value: "61" } }
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "split Color; apply Revenue; combine descending", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          { operation: "filter", type: "not", filter: { type: "in", attribute: "table", values: [ "61", "65" ] } }
          { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
          { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      query: [
        { operation: "filter", type: "not", filter: { type: "in", attribute: "table", values: [ "61", "65" ] } }
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }


  describe "multiple splits", ->
    setUpQuery = new FacetQuery [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "add more tests"


  describe "filtered splits cache", ->
    setUpQuery = new FacetQuery [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      {
        operation: 'split'
        name: 'Cut'
        bucket: 'identity'
        attribute: 'cut'
        segmentFilter: {
          prop: 'Color'
          type: 'in'
          values: ['E', 'I']
        }
      }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "works with included segment filter", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        {
          operation: 'split'
          name: 'Cut'
          bucket: 'identity'
          attribute: 'cut'
          segmentFilter: {
            prop: 'Color'
            type: 'in'
            values: ['E']
          }
        }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "works when adding a new element outside filter", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          { operation: 'filter', type: 'is', attribute: 'color', value: 'G' }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        {
          operation: 'split'
          name: 'Cut'
          bucket: 'identity'
          attribute: 'cut'
          segmentFilter: {
            prop: 'Color'
            type: 'in'
            values: ['I', 'G']
          }
        }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "only with a new element", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = new FacetQuery [
          { operation: 'filter', type: 'is', attribute: 'color', value: 'H' }
          { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
          { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        ]
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        {
          operation: 'split'
          name: 'Cut'
          bucket: 'identity'
          attribute: 'cut'
          segmentFilter: {
            prop: 'Color'
            type: 'in'
            values: ['H']
          }
        }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "combine all filters", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        {
          operation: 'split'
          name: 'Cut'
          bucket: 'identity'
          attribute: 'cut'
          segmentFilter: {
            prop: 'Color'
            type: 'in'
            values: ['E', 'H', 'I', 'G']
          }
        }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }

    it "same filter in a different order", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = false
      query: [
        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
        {
          operation: 'split'
          name: 'Cut'
          bucket: 'identity'
          attribute: 'cut'
          segmentFilter: {
            prop: 'Color'
            type: 'in'
            values: ['I', 'E']
          }
        }
        { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
      ]
    }


  describe "time split cache", ->
    describe "without filters", ->
      setUpQuery = new FacetQuery [
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        {
          operation: 'apply'
          name: 'AvgDeleted'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'deleted' }
            { aggregate: 'sum', attribute: 'count' }
          ]
        }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
            { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "split time; apply count", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; filter within another time filter", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-26T12:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; limit", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
        ]
      }

      it "split time; apply count; combine count, descending (positive metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: "apply", name: "count", aggregate: "sum", attribute: "count" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "count", direction: "descending" }, "limit": 5 }
        ]
      }

      it "split time; apply count; combine count, ascending (positive metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: "apply", name: "count", aggregate: "sum", attribute: "count" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "count", direction: "ascending" }, "limit": 5 }
        ]
      }

      it "split time; apply deleted; combine deleted, descending (negative metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: "apply", name: "deleted", aggregate: "sum", attribute: "deleted" }
            { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "descending" }, "limit": 5 }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: "apply", name: "deleted", aggregate: "sum", attribute: "deleted" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "descending" }, "limit": 5 }
        ]
      }

      it "split time; apply deleted; combine deleted, ascending (negative metrics)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: "apply", name: "deleted", aggregate: "sum", attribute: "deleted" }
            { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "ascending" }, "limit": 5 }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: "apply", name: "deleted", aggregate: "sum", attribute: "deleted" }
          { operation: "combine", combine: "slice", sort: { compare: "natural", prop: "deleted", direction: "ascending" }, "limit": 5 }
        ]
      }


    describe "filtered on one thing", ->
      setUpQuery = new FacetQuery [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          ]
        }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "filter; split time; apply count; apply added", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }

      it "filter; split time; apply added; combine time descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }


    describe "filtered on two things", ->
      setUpQuery = new FacetQuery [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          ]
        }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "filter; split time; apply count; apply added", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "filter; split time; apply count; apply added; combine time descending", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', attribute: 'namespace', type: 'is', value: 'article' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      }

    describe "cache known unknowns (query more than there is data)", ->
      setUpQuery = new FacetQuery [
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-28T00:00:00Z")] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "split time; apply count", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-28T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; filter within existing range", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count; ascending limit", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-28T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }, limit: 5 }
        ]
      }

      it "split time; apply count; descending limit", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-28T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' }, limit: 5 }
        ]
      }


    describe.skip 'handles time split without time filter', ->
      setUpQuery = [
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }


    describe "sub-query", ->
      setUpQuery = new FacetQuery [
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T02:00:00Z"), new Date("2013-02-26T22:00:00Z")] }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "split time; apply count on larger interval (one missing value)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

      it "split time; apply count on larger interval (two missing values)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T22:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
            { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
            { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T22:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
        ]
      }

  describe "fillTree test", ->
    setUpQuery = new FacetQuery [
      {
        operation: 'filter'
        type: 'and'
        filters: [
          { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
        ]
      }
      { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
    ]

    before ->
      driverFns.wikipediaCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: ->
        expectedQuery = new FacetQuery [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
              { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
        ]
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          ]
        }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
      ]
    }

  describe "splitCache fills filterCache as well", ->
    setUpQuery = new FacetQuery [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.wikipediaCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = false
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
            { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }


  describe "Segment filters cache", ->
    describe 'caches removing an expansions and split', ->
      setUpQuery = [
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        {
          operation: "split", name: "Page", bucket: "identity", attribute: "page",
          segmentFilter: {
            type: "or"
            filters: [
              { type: "is", prop: "Language", value: "fr" }
              { type: "is", prop: "Language", value: "de" }
            ]
          }
        }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "collapses one level", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Language", value: "fr" }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "collapses another level (to empty)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "false"
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "removes the empty split", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }


    describe 'caches adding a split and expansions (identity)', ->
      setUpQuery = [
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "adds an empty split (without querying)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "false"
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "adds an expansion", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "is", attribute: "language", value: "en" }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Language", value: "en" }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "adds another expansion", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "is", attribute: "language", value: "fr" }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Language", value: "en" }
                { type: "is", prop: "Language", value: "fr" }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "adds an expansion that does not exist", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "is", attribute: "language", value: "poo" }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Language", value: "en" }
                { type: "is", prop: "Language", value: "fr" }
                { type: "is", prop: "Language", value: "poo" }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "filters", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: "filter", type: "is", attribute: "language", value: "en" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }


    describe 'caches adding a split and expansions (time)', ->
      setUpQuery = [
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
        { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
        { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      ]

      before ->
        driverFns.wikipediaCached.clear()

      it "runs the initial query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = setUpQuery
        query: setUpQuery
      }

      it "caches the set up query", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: setUpQuery
      }

      it "adds an empty split (without querying)", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: -> expectedQuery = false
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "false"
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "adds an expansion", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "within", attribute: "time", range: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Time", value: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
        after: (err, result) ->
          expect(result.splits[1])
            .to.have.property('splits')
            .that.is.an('array')
      }

      it "adds another expansion", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "within", attribute: "time", range: [new Date("2013-02-26T15:00:00Z"), new Date("2013-02-26T16:00:00Z")] }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Time", value: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
                { type: "is", prop: "Time", value: [new Date("2013-02-26T15:00:00Z"), new Date("2013-02-26T16:00:00Z")] }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
        after: (err, result) ->
          expect(result.splits[2])
            .to.have.property('splits')
            .that.is.an('array')
      }

      it "adds an expansion that does not exist", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: ->
          expectedQuery = new FacetQuery [
            { operation: "filter", type: "within", attribute: "time", range: [new Date("2010-02-26T15:00:00Z"), new Date("2010-02-26T16:00:00Z")] }
            { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
            { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
            { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          ]
        query: [
          { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Time", bucket: "timePeriod", attribute: "time", period: 'PT1H' }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
          {
            operation: "split", name: "Page", bucket: "identity", attribute: "page",
            segmentFilter: {
              type: "or"
              filters: [
                { type: "is", prop: "Time", value: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
                { type: "is", prop: "Time", value: [new Date("2013-02-26T15:00:00Z"), new Date("2013-02-26T16:00:00Z")] }
                { type: "is", prop: "Time", value: [new Date("2010-02-26T15:00:00Z"), new Date("2010-02-26T16:00:00Z")] }
              ]
            }
          }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }

      it "filters", testEquality {
        drivers: ['wikipediaCached', 'wikipedia']
        before: expectedQuery = null
        query: [
          { operation: "filter", type: "within", attribute: "time", range: [new Date("2013-02-26T01:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
          { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
          { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
        ]
      }


  describe "selected applies", ->
    setUpQuery = new FacetQuery [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
      { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
    ]

    before ->
      driverFns.wikipediaCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "caches the set up query", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: -> expectedQuery = false
      query: setUpQuery
    }

    it "filter; split time; apply count; apply added; combine time descending", testEquality {
      drivers: ['wikipediaCached', 'wikipedia']
      before: ->
        expectedQuery = new FacetQuery [
          {
            operation: 'filter'
            type: 'and'
            filters: [
              { type: 'in', attribute: 'language', values: ["de", "en", "fr", "it", "sv"] }
              { type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
            ]
          }
          { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
          { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
          { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
          { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
        ]
      query: [
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] }
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'apply', name: 'Deleted', aggregate: 'sum', attribute: 'deleted' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
      ]
    }


  describe "dayLightSavings checker", ->
    describe "with P1D granularity", ->
      it 'should work well when exiting daylight saving time with P1D granularity', (done) ->
        dayLightSavingsData = new SegmentTree({
          prop: {},
          splits: [
            {prop: {Impressions: 0.013, timerange: ["2012-11-02T07:00:00.000Z", "2012-11-03T07:00:00.000Z"]}},
            {prop: {Impressions: 1.212, timerange: ["2012-11-03T07:00:00.000Z", "2012-11-04T07:00:00.000Z"]}},
            {prop: {Impressions: 1.188, timerange: ["2012-11-04T07:00:00.000Z", "2012-11-05T08:00:00.000Z"]}},
            {prop: {Impressions: 1.021, timerange: ["2012-11-05T08:00:00.000Z", "2012-11-06T08:00:00.000Z"]}},
            {prop: {Impressions: 0.980, timerange: ["2012-11-06T08:00:00.000Z", "2012-11-07T08:00:00.000Z"]}},
            {prop: {Impressions: 0.900, timerange: ["2012-11-07T08:00:00.000Z", "2012-11-08T08:00:00.000Z"]}}
          ]
        })

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
              "name": "Impressions",
              "attribute": "impressions",
              "aggregate": "sum",
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()

      it 'should work well when entering daylight saving time with P1D granularity', (done) ->
        dayLightSavingsData = new SegmentTree({
          "prop": {},
          "splits": [
            {"prop": {"clicks": 2198708, "timerange": ["2013-03-08T08:00:00.000Z", "2013-03-09T08:00:00.000Z"]}},
            {"prop": {"clicks": 2326918, "timerange": ["2013-03-09T08:00:00.000Z", "2013-03-10T08:00:00.000Z"]}},
            {"prop": {"clicks": 2160294, "timerange": ["2013-03-10T08:00:00.000Z", "2013-03-11T07:00:00.000Z"]}},
            {"prop": {"clicks": 2005976, "timerange": ["2013-03-11T07:00:00.000Z", "2013-03-12T07:00:00.000Z"]}}
          ]
        })

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()


      it 'should work well when entering daylight saving time with P1D granularity in UTC', (done) ->
        dayLightSavingsData = new SegmentTree {
          "prop": {},
          "splits": [
            {"prop": { "robot_count": 42, "timerange": ["2013-03-06T00:00:00.000Z","2013-03-07T00:00:00.000Z"]}},
            {"prop": { "robot_count": 53, "timerange": ["2013-03-07T00:00:00.000Z","2013-03-08T00:00:00.000Z"]}},
            {"prop": { "robot_count": 70, "timerange": ["2013-03-08T00:00:00.000Z","2013-03-09T00:00:00.000Z"]}},
            {"prop": { "robot_count": 77, "timerange": ["2013-03-09T00:00:00.000Z","2013-03-10T00:00:00.000Z"]}},
            {"prop": { "robot_count": 70, "timerange": ["2013-03-10T00:00:00.000Z","2013-03-11T00:00:00.000Z"]}},
            {"prop": { "robot_count": 72, "timerange": ["2013-03-11T00:00:00.000Z","2013-03-12T00:00:00.000Z"]}},
            {"prop": { "robot_count": 78, "timerange": ["2013-03-12T00:00:00.000Z","2013-03-13T00:00:00.000Z"]}}
          ]
        }

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
              "name": "robot_count",
              "filter": {
                "type": "is",
                "attribute": "robot",
                "value": "1"
              },
              "aggregate": "sum",
              "attribute": "count",
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()

      it 'should work well when exiting daylight saving time with P1D granularity in UTC', (done) ->
        dayLightSavingsData = new SegmentTree {
          "prop": {},
          "splits": [
            {"prop": {"robot_count": 32, "timerange": ["2012-10-31T00:00:00.000Z","2012-11-01T00:00:00.000Z"]}},
            {"prop": {"robot_count": 32, "timerange": ["2012-11-01T00:00:00.000Z","2012-11-02T00:00:00.000Z"]}},
            {"prop": {"robot_count": 31, "timerange": ["2012-11-02T00:00:00.000Z","2012-11-03T00:00:00.000Z"]}},
            {"prop": {"robot_count": 31, "timerange": ["2012-11-03T00:00:00.000Z","2012-11-04T00:00:00.000Z"]}},
            {"prop": {"robot_count": 34, "timerange": ["2012-11-04T00:00:00.000Z","2012-11-05T00:00:00.000Z"]}},
            {"prop": {"robot_count": 34, "timerange": ["2012-11-05T00:00:00.000Z","2012-11-06T00:00:00.000Z"]}},
            {"prop": {"robot_count": 33, "timerange": ["2012-11-06T00:00:00.000Z","2012-11-07T00:00:00.000Z"]}},
            {"prop": {"robot_count": 34, "timerange": ["2012-11-07T00:00:00.000Z","2012-11-08T00:00:00.000Z"]}},
            {"prop": {"robot_count": 35, "timerange": ["2012-11-08T00:00:00.000Z","2012-11-09T00:00:00.000Z"]}}
          ]
        }

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
              "name": "robot_count",
              "filter": {
                "type": "is",
                "attribute": "robot",
                "value": "1"
              },
              "aggregate": "sum",
              "attribute": "count"
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()


    describe "with PT1H granularity", ->
      it 'should work well when entering daylight saving time with PT1H granularity', (done) ->
        dayLightSavingsData = new SegmentTree {
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

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()

      it 'should work well when exiting daylight saving time with PT1H granularity', (done) ->
        dayLightSavingsData = new SegmentTree {
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

        dayLightSavingsDriver = (request, callback) ->
          callback(null, dayLightSavingsData)
          return

        dayLightSavingsDriverCached = fractalCache({
          driver: dayLightSavingsDriver
        })

        dayLightSavingsDriverCached {
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
          expect(result.valueOf()).to.deep.equal(dayLightSavingsData.valueOf())
          done()


  describe "Matrix cache", ->
    it "returns the right value", (done) ->
      myQuery = new FacetQuery([
        { operation: 'filter', type: 'within', attribute: 'time', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")] },
        { "bucket": "tuple", "splits": [ { "bucket": "identity", "name": "user", "attribute": "user" }, { "bucket": "identity", "name": "language", "attribute": "language" } ], "operation": "split" },
        { "name": "count", "aggregate": "sum", "attribute": "count", "operation": "apply" },
        { "method": "matrix", "sort": { "compare": "natural", "prop": "count", "direction": "descending" }, "limits": [ 20, 20 ], "operation": "combine" }
      ])
      expectedQuery = myQuery
      driverFns.wikipediaCached({
        query: myQuery
      }, (err, result) ->
        expect(err).to.exist
        expect(err).to.have.property('message').that.equals('matrix combine not implemented yet')
        done()
      )


  describe 'Cleans up old values', ->
    setUpQuery = new FacetQuery [
      { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
      { operation: 'apply', name: 'Cheapest', aggregate: 'min', attribute: 'price' }
      { operation: 'apply', name: 'Revenue', aggregate: 'sum', attribute: 'price' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }, limit: 5 }
    ]

    irrelevantQuery = new FacetQuery [
      { operation: 'apply', name: 'Expensive', aggregate: 'max', attribute: 'price' }
    ]

    before ->
      currentTimeOverride = Date.now()
      driverFns.diamondsCached.clear()

    it "runs the initial query", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }

    it "runs some irrelevant query 31 min later", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: ->
        expectedQuery = irrelevantQuery
        currentTimeOverride += 31 * 60 * 1000
      query: irrelevantQuery
      after: ->
        expect(driverFns.diamondsCached.stats()).to.deep.equal({
          applyCache: 1,
          combineToSplitCache: 0
        })
    }

    it "runs the query again", testEquality {
      drivers: ['diamondsCached', 'diamonds']
      before: -> expectedQuery = setUpQuery
      query: setUpQuery
    }
