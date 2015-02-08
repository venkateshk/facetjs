tests = require './sharedTests'

describe 'NumberRangeExpression', ->
  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'numberRange', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 7 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: {start: 5, end: 7}, type: 'NUMBER_RANGE' })

  describe 'with ref', ->
    beforeEach ->
      this.expression = { op: 'numberRange', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'blah' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'numberRange', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'blah' } })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'numberRange', lhs: { op: 'add', operands: [1, 2, 4] }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(6)
    tests.simplifiedExpressionIs({ op: 'literal', value: {start: 7, end: 5}, type: 'NUMBER_RANGE' })
