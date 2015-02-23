{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Set } = facet.core

describe "Set", ->
  it "passes higher object tests", ->
    testHigherObjects(Set, [
      {
        type: 'BOOLEAN'
        values: [true]
      }
      {
        type: 'STRING'
        values: []
      }
      {
        type: 'STRING'
        values: ['A']
      }
      {
        type: 'STRING'
        values: ['B', 'C']
      }
      {
        type: 'NUMBER'
        values: []
      }
      {
        type: 'NUMBER'
        values: [1, 2]
      }
      {
        type: 'NUMBER_RANGE'
        values: [
          { start: 1, end: 2 }
          { start: 3, end: 5 }
        ]
      }
      {
        type: 'TIME'
        values: [new Date("2015-02-21T00:00:00"), new Date("2015-02-20T00:00:00")]
      }
      {
        type: 'TIME_RANGE'
        values: [
          { start: new Date("2015-02-20T00:00:00"), end: new Date("2015-02-21T00:00:00") }
          { start: new Date("2015-02-22T00:00:00"), end: new Date("2015-02-24T00:00:00") }
        ]
      }
    ])

  describe "#add()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).add('C').toJS()
      ).to.deep.equal({
        type: 'STRING'
        values: ['A', 'B', 'C']
      })

  describe "#union()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).union(Set.fromJS(['B', 'C'])).toJS()
      ).to.deep.equal({
        type: 'STRING'
        values: ['A', 'B', 'C']
      })

  describe "#intersect()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).intersect(Set.fromJS(['B', 'C'])).toJS()
      ).to.deep.equal({
        type: 'STRING'
        values: ['B']
      })
