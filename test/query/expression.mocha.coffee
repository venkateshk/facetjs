{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/query/expression')

describe "Expression", ->
  it "passes higher object tests", ->

    testHigherObjects(Expression, [
      {
        op: 'literal'
        value: 5
      }
      {
        op: 'literal'
        value: 'facet'
      }
      {
        op: 'lookup'
        name: 'hello'
      }
      {
        op: 'lookup'
        name: 'goodbye'
      }
      {
        op: 'equals'
        lhs: { op: 'lookup', name: 'hello' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'equals'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
    ], {
      newThrows: true
    })