{ expect } = require("chai")

tests = require './sharedTests'

describe 'NotExpression', ->
  describe 'with false expression', ->
    beforeEach ->
      this.expression = { op: 'not', operand: { op: 'literal', value: true } }

    tests.expressionCountIs(2)
    tests.simplifiedExpressionIs({op: 'literal', value: false})

  describe 'with true expression', ->
    beforeEach ->
      this.expression = { op: 'not', operand: { op: 'literal', value: false } }

    tests.expressionCountIs(2)
    tests.simplifiedExpressionIs({op: 'literal', value: true})

  describe 'with reference expression', ->
    beforeEach ->
      this.expression = { op: 'not', operand: { op: 'ref', name: 'test' } }

    tests.expressionCountIs(2)
    tests.simplifiedExpressionIs({ op: 'not', operand: { op: 'ref', name: 'test' } })
