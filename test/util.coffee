
{ expect } = require('chai')
Applies = require('../src/query/apply')
Queries = require('../src/query/query')
util = require('../src/util')

describe 'util', ->
  describe 'isInstanceOf', ->
    it 'returns true correctly', ->
      applySpec = {
        name: "Count"
        aggregate: 'constant'
        value: 42
      }
      expect(util.isInstanceOf(Applies.FacetApply.fromSpec(applySpec), Applies.FacetApply)).to.be.true

    it 'returns false correctly', ->
      applySpec = {
        name: "Count"
        aggregate: 'constant'
        value: 42
      }
      expect(util.isInstanceOf(Applies.FacetApply.fromSpec(applySpec), Queries.FacetQuery)).to.be.false
