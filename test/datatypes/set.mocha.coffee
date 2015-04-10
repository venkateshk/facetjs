{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../build/facet')
{ Set, $ } = facet

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
        setType: 'STRING'
        elements: ['B', 'hasOwnProperty', 'troll']
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
        elements: [new Date("2015-02-20T00:00:00"), new Date("2015-02-21T00:00:00")]
      }
      {
        setType: 'TIME_RANGE'
        elements: [
          { start: new Date("2015-02-20T00:00:00"), end: new Date("2015-02-21T00:00:00") }
          { start: new Date("2015-02-22T00:00:00"), end: new Date("2015-02-24T00:00:00") }
        ]
      }
    ])

  describe "does not die with hasOwnProperty", ->
    it "survives", ->
      expect(Set.fromJS({
        setType: 'NUMBER'
        elements: [1, 2]
        hasOwnProperty: 'troll'
      }).toJS()).to.deep.equal({
        setType: 'NUMBER'
        elements: [1, 2]
      })

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

    it 'works correctly with troll', ->
      expect(
        Set.fromJS(['A', 'B']).union(Set.fromJS(['B', 'C', 'hasOwnProperty'])).toJS()
      ).to.deep.equal({
        setType: 'STRING'
        elements: ['A', 'B', 'C', 'hasOwnProperty']
      })

  describe "#intersect()", ->
    it 'works correctly', ->
      expect(
        Set.fromJS(['A', 'B']).intersect(Set.fromJS(['B', 'C'])).toJS()
      ).to.deep.equal({
        setType: 'STRING'
        elements: ['B']
      })

    it 'works correctly with troll', ->
      expect(
        Set.fromJS(['A', 'B', 'hasOwnProperty']).intersect(Set.fromJS(['B', 'C', 'hasOwnProperty'])).toJS()
      ).to.deep.equal({
        setType: 'STRING'
        elements: ['B', 'hasOwnProperty']
      })
