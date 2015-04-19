{ expect } = require("chai")

tests = require './sharedTests'
describe 'MultiplyExpression', ->
  describe 'with only literal values', ->
    beforeEach ->
      this.expression = { op: 'multiply', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 4 }] }

    tests.expressionCountIs(4)
    tests.simplifiedExpressionIs({
      op: 'literal'
      value: -240
    })

  describe 'with one ref value', ->
    beforeEach ->
      this.expression = { op: 'multiply', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 4 }] }

    tests.expressionCountIs(4)
    tests.simplifiedExpressionIs({ op: 'multiply', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -48 }] })

  describe 'with two ref values', ->
    beforeEach ->
      this.expression = { op: 'multiply', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 4 }, { op: 'ref', name: 'test2' }] }

    tests.expressionCountIs(5)
    tests.simplifiedExpressionIs({ op: 'multiply', operands: [{ op: 'ref', name: 'test' }, { op: 'ref', name: 'test2' }, { op: 'literal', value: -48 }] })

  describe 'with no values', ->
    beforeEach ->
      this.expression = { op: 'multiply', operands: [] }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 1 })
