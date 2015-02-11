{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Set } = facet.core

describe "Set", ->
  it "passes higher object tests", ->
    testHigherObjects(Set, [
      {
        values: []
      }
      {
        values: ['1']
      }
      {
        values: ['2', '3']
      }
    ])

  describe "#union()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS({values: ['1', '2']}).union(Set.fromJS({values: ['2', '3']})).toJS()
      ).to.deep.equal({values: ['1', '2', '3']})

  describe "#intersect()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS({values: ['1', '2']}).intersect(Set.fromJS({values: ['2', '3']})).toJS()
      ).to.deep.equal({values: ['2']})
