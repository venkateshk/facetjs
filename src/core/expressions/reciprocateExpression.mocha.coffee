tests = require './sharedTests'

describe 'ReciprocateExpression', ->
  describe 'with literal value', ->
    beforeEach ->
      this.expression = { op: 'reciprocate', operand: { op: 'literal', value: 5 } }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({op: 'literal', value: 0.2})

  describe 'with reference value', ->
    beforeEach ->
      this.expression = { op: 'reciprocate', operand: { op: 'ref', name: 'test' } }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({ op: 'reciprocate', operand: { op: 'ref', name: 'test' } })

  describe 'with complex value', ->
    beforeEach ->
      this.expression = { op: 'reciprocate', operand: { op: 'add', operands: [{ op: 'literal', value: 2 }, { op: 'literal', value: 2 }] } }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'literal', value: 0.25})
