{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ TimeRange } = facet.core

describe "TimeRange", ->
  it "passes higher object tests", ->
    testHigherObjects(TimeRange, [
      {
        start: new Date('2015-01-26T04:54:10Z')
        end:   new Date('2015-01-26T05:54:10Z')
      }
      {
        start: new Date('2015-01-26T04:54:10Z')
        end:   new Date('2015-01-26T05:00:00Z')
      }
    ])

  describe "does not die with hasOwnProperty", ->
    it "survives", ->
      expect(TimeRange.fromJS({
        start: new Date('2015-01-26T04:54:10Z')
        end:   new Date('2015-01-26T05:54:10Z')
        hasOwnProperty: 'troll'
      }).toJS()).to.deep.equal({
        start: new Date('2015-01-26T04:54:10Z')
        end:   new Date('2015-01-26T05:54:10Z')
      })

  describe "upgrades", ->
    it "upgrades from a string", ->
      timeRange = TimeRange.fromJS({
        start: '2015-01-26T04:54:10Z'
        end:   '2015-01-26T05:00:00Z'
      })
      expect(timeRange.start.valueOf()).to.equal(Date.parse('2015-01-26T04:54:10Z'))
      expect(timeRange.end.valueOf()  ).to.equal(Date.parse('2015-01-26T05:00:00Z'))

  describe "#union()", ->
    it 'works correctly with a non-disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T02:00:00' }).union(TimeRange.fromJS({ start: '2015-01-26T01:00:00', end: '2015-01-26T03:00:00' })).toJS()
      ).to.deep.equal({ start: new Date('2015-01-26T00:00:00'), end: new Date('2015-01-26T03:00:00') })

    it 'works correctly with a disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T01:00:00' }).union(TimeRange.fromJS({ start: '2015-01-26T02:00:00', end: '2015-01-26T03:00:00' }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T01:00:00' }).union(TimeRange.fromJS({ start: '2015-01-26T01:00:00', end: '2015-01-26T02:00:00' }))
      ).to.deep.equal(null)

  describe "#intersect()", ->
    it 'works correctly with a non-disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T02:00:00' }).intersect(TimeRange.fromJS({ start: '2015-01-26T01:00:00', end: '2015-01-26T03:00:00' })).toJS()
      ).to.deep.equal({ start: new Date('2015-01-26T01:00:00'), end: new Date('2015-01-26T02:00:00') })

    it 'works correctly with a disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T01:00:00' }).intersect(TimeRange.fromJS({ start: '2015-01-26T02:00:00', end: '2015-01-26T03:00:00' }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        TimeRange.fromJS({ start: '2015-01-26T00:00:00', end: '2015-01-26T01:00:00' }).intersect(TimeRange.fromJS({ start: '2015-01-26T01:00:00', end: '2015-01-26T02:00:00' }))
      ).to.deep.equal(null)
