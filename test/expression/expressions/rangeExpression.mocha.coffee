{ expect } = require("chai")

tests = require './sharedTests'

describe 'RangeExpression', ->
  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

  describe 'with ref', ->
    beforeEach ->
      this.expression = { op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'blah' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'blah' } })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'range', lhs: { op: 'add', operands: [1, 2, 4] }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(6)
    tests.simplifiedExpressionIs({ op: 'range', lhs: { op: 'literal', value: 7 }, rhs: { op: 'literal', value: 5 } })
