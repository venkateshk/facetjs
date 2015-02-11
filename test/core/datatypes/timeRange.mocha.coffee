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
        TimeRange.fromJS({ start: 0, end: 2 }).union(TimeRange.fromJS({ start: 1, end: 3 })).toJS()
      ).to.deep.equal({ start: 0, end: 3 })

    it 'works correctly with a disjoint set', ->
      expect(
        TimeRange.fromJS({ start: 0, end: 1 }).union(TimeRange.fromJS({ start: 2, end: 3 }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        TimeRange.fromJS({ start: 0, end: 1 }).union(TimeRange.fromJS({ start: 1, end: 2 }))
      ).to.deep.equal(null)

  describe "#intersect()", ->
    it 'works correctly with a non-disjoint set', ->
      expect(
        TimeRange.fromJS({ start: 0, end: 2 }).intersect(TimeRange.fromJS({ start: 1, end: 3 })).toJS()
      ).to.deep.equal({ start: 1, end: 2 })

    it 'works correctly with a disjoint set', ->
      expect(
        TimeRange.fromJS({ start: 0, end: 1 }).intersect(TimeRange.fromJS({ start: 2, end: 3 }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        TimeRange.fromJS({ start: 0, end: 1 }).intersect(TimeRange.fromJS({ start: 1, end: 2 }))
      ).to.deep.equal(null)
