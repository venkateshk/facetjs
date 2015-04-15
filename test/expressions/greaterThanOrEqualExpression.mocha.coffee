{ expect } = require("chai")

tests = require './sharedTests'
describe 'GreaterThanOrEqualExpression', ->
  describe 'with false literal values', ->
    beforeEach ->
      this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 6 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: false})

  describe 'with true literal values', ->
    beforeEach ->
      this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: true})

  describe 'with reference (5 >= $flight_time)', ->
    beforeEach ->
      this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({
      "lhs": {
        "name": "flight_time"
        "op": "ref"
      }
      "op": "in"
      "rhs": {
        "op": "literal"
        "type": "NUMBER_RANGE"
        "value": {
          "start": null
          "end": 5
          "bounds": "(]"
        }
      }
    })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 7 }, rhs: { op: 'add', operands: [{ op: 'literal', value: 3 }, { op: 'literal', value: 3 }] } }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({op:'literal', value: true})
