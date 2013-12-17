chai = require("chai")
expect = chai.expect

{FacetCombine} = require('../../src/query')

describe "FacetCombine", ->
  describe "preserves", ->
    it "slice", ->
      combineSpec = {
        method: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
      }
      expect(FacetCombine.fromSpec(combineSpec).valueOf()).to.deep.equal(combineSpec)

