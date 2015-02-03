tests = require './sharedTests'

describe 'NegateExpression', ->
  describe 'with literal value', ->
    beforeEach ->
      this.expression = { op: 'negate', operand: { op: 'literal', value: 1 } }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({op: 'literal', value: -1})

  describe 'with reference value', ->
    beforeEach ->
      this.expression = { op: 'negate', operand: { op: 'ref', name: 'test' } }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({ op: 'negate', operand: { op: 'ref', name: 'test' } })

  describe 'with complex value', ->
    beforeEach ->
      this.expression = { op: 'negate', operand: { op: 'add', operands: [{ op: 'literal', value: 1 }, { op: 'literal', value: 2 }] } }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'literal', value: -3})
