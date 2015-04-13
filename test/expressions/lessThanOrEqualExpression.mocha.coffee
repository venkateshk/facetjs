{ expect } = require("chai")

tests = require './sharedTests'

describe 'LessThanOrEqualExpression', ->
  describe 'with false literal values', ->
    beforeEach ->
      this.expression = { op: 'lessThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 3 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: false})

  describe 'with true literal values', ->
    beforeEach ->
      this.expression = { op: 'lessThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: true})

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'lessThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'add', operands: [{ op: 'literal', value: 3 }, { op: 'literal', value: 3 }] } }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({op:'literal', value: true})

