{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Actions } = require('../../build/expression')

describe "Actions", ->
  it "passes higher object tests", ->
    testHigherObjects(Actions, [
      {
        action: 'apply'
        name: 'five'
        expression: { op: 'literal', value: 5 }
      }
    ])