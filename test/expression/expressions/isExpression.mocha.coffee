{ expect } = require("chai")

tests = require './sharedTests'
describe 'IsExpression', ->
  describe 'with true value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with false value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 2 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })

  describe 'with string value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: 'abc', rhs: 'abc' }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with reference', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'is', lhs: 1, rhs: 2 }, rhs: { op: 'is', lhs: 5, rhs: 2 }}

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })
