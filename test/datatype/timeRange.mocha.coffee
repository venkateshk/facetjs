{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ TimeRange } = require('../../build/datatype/timeRange')

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
