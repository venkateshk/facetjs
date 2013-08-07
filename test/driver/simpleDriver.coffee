chai = require("chai")
expect = chai.expect
utils = require('../utils')

simpleDriver = require('../../build/simpleDriver')
{ FacetQuery } = require('../../build/query')

diamondsData = require('../../data/diamonds.js')
diamondsDriver = simpleDriver(diamondsData)

verbose = false

describe "simple driver", ->
  it "computes the correct count", (done) ->
    querySpec = [
      { operation: 'apply', name: 'Count', aggregate: 'count' }
    ]
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
      expect(result).to.deep.equal({
        prop: {
          Count: 53940
        }
      })

  it "does a split", (done) ->
    querySpec = [
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }
    ]
    diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
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

