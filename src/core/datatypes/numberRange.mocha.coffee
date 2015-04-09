{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ NumberRange } = facet

describe "NumberRange", ->
  it "passes higher object tests", ->
    testHigherObjects(NumberRange, [
      {
        start: 0
        end:   1
      }
      {
        start: 7
        end:   9
      }
      {
        start: 7
        end:   'Infinity'
      }
    ])

  describe "does not die with hasOwnProperty", ->
    it "survives", ->
      expect(NumberRange.fromJS({
        start: 7
        end:   9
        hasOwnProperty: 'troll'
      }).toJS()).to.deep.equal({
        start: 7
        end:   9
      })

  describe "errors", ->
    it "throws on bad numbers", ->
      expect(->
        NumberRange.fromJS({
          start: 'lol'
          end:   'wat'
        })
      ).to.throw('`start` must be a number')

  describe "#union()", ->
    it 'works correctly with a non-disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 2 }).union(NumberRange.fromJS({ start: 1, end: 3 })).toJS()
      ).to.deep.equal({ start: 0, end: 3 })

    it 'works correctly with a disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 1 }).union(NumberRange.fromJS({ start: 2, end: 3 }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 1 }).union(NumberRange.fromJS({ start: 1, end: 2 }))
      ).to.deep.equal(null)

  describe "#intersect()", ->
    it 'works correctly with a non-disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 2 }).intersect(NumberRange.fromJS({ start: 1, end: 3 })).toJS()
      ).to.deep.equal({ start: 1, end: 2 })

    it 'works correctly with a disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 1 }).intersect(NumberRange.fromJS({ start: 2, end: 3 }))
      ).to.deep.equal(null)

    it 'works correctly with a close disjoint set', ->
      expect(
        NumberRange.fromJS({ start: 0, end: 1 }).intersect(NumberRange.fromJS({ start: 1, end: 2 }))
      ).to.deep.equal(null)
