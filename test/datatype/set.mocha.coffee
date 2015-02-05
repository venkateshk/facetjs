{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Set } = require('../../build/datatype/set')

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
