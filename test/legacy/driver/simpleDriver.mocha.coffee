{ expect } = require("chai")

utils = require('../utils')

{ simpleDriver } = require('../../build/driver/simpleDriver')
{ FacetQuery } = require('../../build/query')

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

diamondsData = require('../../data/diamonds.js')
diamondsDriver = simpleDriver(diamondsData)

wikiData = require('../../data/wikipedia.js')
wikiDriver = simpleDriver(wikiData)


verbose = false

describe "simple driver", ->
  it "introspects", (done) ->
    wikiDriver.introspect null, (err, attributes) ->
      expect(attributes).to.deep.equal([
        {
          "name": "added",
          "numeric": true,
          "integer": true
        },
        {
          "name": "anonymous",
          "numeric": true,
          "integer": true
        },
        {
          "name": "count",
          "numeric": true,
          "integer": true
        },
        {
          "name": "deleted",
          "numeric": true,
          "integer": true
        },
        {
          "name": "delta",
          "numeric": true,
          "integer": true
        },
        {
          "name": "geo",
          "categorical": true
        },
        {
          "name": "language",
          "categorical": true
        },
        {
          "name": "namespace",
          "categorical": true
        },
        {
          "name": "newPage",
          "numeric": true,
          "integer": true
        },
        {
          "name": "page",
          "categorical": true
        },
        {
          "name": "robot",
          "numeric": true,
          "integer": true
        },
        {
          "name": "time",
          "time": true,
          "categorical": true
        },
        {
          "name": "unpatrolled",
          "numeric": true,
          "integer": true
        },
        {
          "name": "user",
          "categorical": true
        }
      ])
      done()

  it "computes the correct count", (done) ->
    querySpec = [
      { operation: 'apply', name: 'Count', aggregate: 'count' }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        prop: {
          Count: 53940
        }
      })
      done()

  it "does a split", (done) ->
    querySpec = [
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {},
        "splits": [
          {
            "prop": {
              "Cut": "Ideal",
              "Count": 21551
            }
          },
          {
            "prop": {
              "Cut": "Premium",
              "Count": 13791
            }
          }
        ]
      })
      done()

  it "does a sort-by-delta after split", (done) ->
    querySpec = [
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
        operation: 'combine'
        method: 'slice'
        sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
        limit: 4
      }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {},
        "splits": [
          {
            "prop": {
              "Clarity": "I1",
              "PriceDiff": 739.0906107305941
            }
          },
          {
            "prop": {
              "Clarity": "VVS1",
              "PriceDiff": 213.35526419465123
            }
          },
          {
            "prop": {
              "Clarity": "SI2",
              "PriceDiff": 175.69178632392868
            }
          },
          {
            "prop": {
              "Clarity": "VVS2",
              "PriceDiff": 171.18170816137035
            }
          }
        ]
      })
      done()

  it "does two splits with segment filter", (done) ->
    querySpec = [
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }

      {
        operation: 'split'
        name: 'Clarity', bucket: 'identity', attribute: 'clarity'
        segmentFilter: {
          type: 'in'
          prop: 'Cut'
          values: ['Ideal', 'Strange']
        }
      }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 2 }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {},
        "splits": [
          {
            "prop": {
              "Cut": "Ideal",
              "Count": 21551
            },
            "splits": [
              {
                "prop": {
                  "Clarity": "VS2",
                  "Count": 5071
                }
              },
              {
                "prop": {
                  "Clarity": "SI1",
                  "Count": 4282
                }
              }
            ]
          },
          {
            "prop": {
              "Cut": "Premium",
              "Count": 13791
            }
          }
        ]
      })
      done()

  it "does handles nothingness", (done) ->
    querySpec = [
      { operation: 'filter', type: 'false' }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {}
      })
      done()

  it "does handles nothingness with apply", (done) ->
    querySpec = [
      { operation: 'filter', type: 'false' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {
          "Count": 0
        }
      })
      done()

  it "does handles nothingness with split", (done) ->
    querySpec = [
      { operation: 'filter', type: 'false' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }

      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }
    ]
    diamondsDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {
          "Count": 0
        }
        "splits": []
      })
      done()

  it "does a maxTime query", (done) ->
    querySpec = [
      { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
    ]
    wikiDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        prop: {
          Max: new Date(1361919600000)
        }
      })
      done()

  it "does a minTime query", (done) ->
    querySpec = [
      { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
    ]
    wikiDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        prop: {
          Min: new Date(1361836800000)
        }
      })
      done()

  it "filters on a numeric dimension", (done) ->
    querySpec = [
      { operation: 'filter', type: 'contains', attribute: 'robot', value: '1' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
    ]
    wikiDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {
          "Count": 19106
        }
      })
      done()

  it "splits on time correctly", (done) ->
    timeData = [
      "2013-09-02T00:00:00.000Z"
      "2013-09-02T01:00:00.000Z"
      "2013-09-02T02:00:00.000Z"
      "2013-09-02T03:00:00.000Z"
      "2013-09-02T04:00:00.000Z"
      "2013-09-02T05:00:00.000Z"
      "2013-09-02T06:00:00.000Z"
      "2013-09-02T07:00:00.000Z"
    ].map((d, i) -> { time: new Date(d), place: i })
    timeDriver = simpleDriver(timeData)
    querySpec = [
      { operation: 'split', name: 'Time', attribute: 'time', bucket: 'timePeriod', period: 'PT1H' }
      { operation: 'apply', name: 'Place', aggregate: 'sum', attribute: 'place' }
      { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending'} }
    ]

    timeDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {},
        "splits": [
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T00:00:00.000Z"),
                new Date("2013-09-02T01:00:00.000Z")
              ],
              "Place": 0
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T01:00:00.000Z"),
                new Date("2013-09-02T02:00:00.000Z")
              ],
              "Place": 1
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T02:00:00.000Z"),
                new Date("2013-09-02T03:00:00.000Z")
              ],
              "Place": 2
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T03:00:00.000Z"),
                new Date("2013-09-02T04:00:00.000Z")
              ],
              "Place": 3
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T04:00:00.000Z"),
                new Date("2013-09-02T05:00:00.000Z")
              ],
              "Place": 4
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T05:00:00.000Z"),
                new Date("2013-09-02T06:00:00.000Z")
              ],
              "Place": 5
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T06:00:00.000Z"),
                new Date("2013-09-02T07:00:00.000Z")
              ],
              "Place": 6
            }
          },
          {
            "prop": {
              "Time": [
                new Date("2013-09-02T07:00:00.000Z"),
                new Date("2013-09-02T08:00:00.000Z")
              ],
              "Place": 7
            }
          }
        ]
      })
      done()

  it "splits identity correctly", (done) ->
    querySpec = [
      {
        "type": "and",
        "filters": [
          {
            "type": "within",
            "attribute": "time",
            "range": [
              "2013-02-24T12:00:00.000Z",
              "2013-03-01T00:00:00.001Z"
            ]
          },
          {
            "type": "in",
            "attribute": "language",
            "values": [
              "en"
            ]
          }
        ],
        "operation": "filter"
      },
      {
        "bucket": "identity",
        "name": "unpatrolled",
        "attribute": "unpatrolled",
        "operation": "split"
      },
      {
        "name": "count",
        "aggregate": "sum",
        "attribute": "count",
        "operation": "apply"
      },
      {
        "method": "slice",
        "sort": {
          "compare": "natural",
          "prop": "count",
          "direction": "descending"
        },
        "limit": 13,
        "operation": "combine"
      }
    ]

    wikiDriver { query: FacetQuery.fromJS(querySpec) }, (err, result) ->
      expect(err).to.not.exist
      expect(result.toJS()).to.deep.equal({
        "prop": {},
        "splits": [
          {
            "prop": {
              "unpatrolled": 0,
              "count": 16384
            }
          },
          {
            "prop": {
              "unpatrolled": 1,
              "count": 191
            }
          }
        ]
      })
      done()



