chai = require("chai")
expect = chai.expect

{FacetCombine} = require('../../target/query')

describe "combine", ->
  describe "preserves", ->
    it "slice", ->
      combineSpec = {
        method: 'slice'
        sort: { compare: 'natural', prop: 'Time', direction: 'ascending' }
      }
      expect(FacetCombine.fromSpec(combineSpec).valueOf()).to.deep.equal(combineSpec)

