chai = require("chai")
expect = chai.expect
utils = require('../utils')

simpleDriver = require('../../build/simpleDriver')
{ FacetQuery } = require('../../build/query')

diamondsData = require('../../data/diamonds.js')
diamondsDriver = simpleDriver(diamondsData)

wikiData = require('../../data/wikipedia.js')
wikiDriver = simpleDriver(wikiData)


verbose = false

describe "simple driver", ->
  it "computes the correct count", (done) ->
    querySpec = [
      { operation: 'apply', name: 'Count', aggregate: 'count' }
    ]
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      expect(result).to.deep.equal({
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
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      expect(result).to.deep.equal({
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

  it.only "does a sort-by-delta after split", (done) ->
    querySpec = [
      {
        operation: 'dataset'
        datasets: ['ideal-cut', 'premium-cut']
      }
      {
        operation: 'filter'
        dataset: 'ideal-cut'
        type: 'is'
        attribute: 'cut'
        value: 'Ideal'
      }
      {
        operation: 'filter'
        dataset: 'premium-cut'
        type: 'is'
        attribute: 'cut'
        value: 'Premium'
      }
      {
        operation: 'split'
        dataset: 'ideal-cut'
        name: 'Color'
        bucket: 'identity'
        attribute: 'color'
      }
      {
        operation: 'split'
        dataset: 'premium-cut'
        name: 'Color'
        bucket: 'identity'
        attribute: 'color'
      }
      {
        operation: 'apply'
        name: 'PriceDiff'
        arithmetic: 'subtract'
        opperands: [
          {
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            dataset: 'premium-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
      }
      {
        operation: 'combine'
        method: 'slice'
        sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
      }
    ]
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      console.log JSON.stringify(result, null, 2)
      expect(result).to.deep.equal({
        p: '?'
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
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      expect(result).to.deep.equal({
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

  it "does a maxTime query", (done) ->
    querySpec = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(2000, 0, 1), new Date(3000, 0, 1)] }
      { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
    ]
    wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      expect(result).to.deep.equal({ prop: { Max: 1361919600000 } })
      done()

  it "does a minTime query", (done) ->
    querySpec = [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(2000, 0, 1), new Date(3000, 0, 1)] }
      { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
    ]
    wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(err).to.equal(null)
      expect(result).to.deep.equal({ prop: { Min: 1361836800000 } })
      done()

