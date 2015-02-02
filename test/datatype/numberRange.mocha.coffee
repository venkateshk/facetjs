{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ NumberRange } = require('../../build/datatype/numberRange')

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

  describe "errors", ->
    it "throws on bad numbers", ->
      expect(->
        NumberRange.fromJS({
          start: 'lol'
          end:   'wat'
        })
      ).to.throw('`start` must be a number')
