{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Set } = facet.core

describe "Set", ->
  it "passes higher object tests", ->
    testHigherObjects(Set, [
      {
        setType: 'BOOLEAN'
        elements: [true]
      }
      {
        setType: 'STRING'
        elements: []
      }
      {
        setType: 'STRING'
        elements: ['A']
      }
      {
        setType: 'STRING'
        elements: ['B', 'C']
      }
      {
        setType: 'NUMBER'
        elements: []
      }
      {
        setType: 'NUMBER'
        elements: [1, 2]
      }
      {
        setType: 'NUMBER_RANGE'
        elements: [
          { start: 1, end: 2 }
          { start: 3, end: 5 }
        ]
      }
      {
        setType: 'TIME'
        elements: [new Date("2015-02-21T00:00:00"), new Date("2015-02-20T00:00:00")]
      }
      {
        setType: 'TIME_RANGE'
        elements: [
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
        setType: 'STRING'
        elements: ['A', 'B', 'C']
      })

  describe "#union()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).union(Set.fromJS(['B', 'C'])).toJS()
      ).to.deep.equal({
        setType: 'STRING'
        elements: ['A', 'B', 'C']
      })

  describe "#intersect()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).intersect(Set.fromJS(['B', 'C'])).toJS()
      ).to.deep.equal({
        setType: 'STRING'
        elements: ['B']
      })
