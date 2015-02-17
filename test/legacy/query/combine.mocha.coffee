{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require("../../../build/facet")
{ FacetCombine } = facet.legacy

describe "FacetCombine", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetCombine, [
      {
        method: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
      }
      {
        method: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
        limit: 10
      }
      {
        method: 'slice'
        sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }
        limit: 10
      }
      {
        method: 'matrix'
        sort: { compare: 'natural', prop: 'Revenue', direction: 'descending' }
        limits: [10, 12]
      }
    ], {
      newThrows: true
    })

  describe "back compatibility", ->
    it "slice", ->
      combineSpec = {
        combine: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
      }
      expect(FacetCombine.fromJS(combineSpec).toJS()).to.deep.equal({
        method: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
      })

