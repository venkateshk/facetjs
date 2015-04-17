{ expect } = require("chai")

tests = require './sharedTests'

describe 'ConcatExpression', ->
  describe 'with literal values', ->
    beforeEach ->
      this.expression = { op: 'concat', operands: [
        { op: 'literal', value: 'Honda' },
        { op: 'literal', value: 'BMW' },
        { op: 'literal', value: 'Suzuki' }
      ]}

    tests.expressionCountIs(4)
    tests.simplifiedExpressionIs({op: 'literal', value: 'HondaBMWSuzuki'})

  describe 'with ref values', ->
    beforeEach ->
      this.expression = { op: 'concat', operands: [
        { op: 'literal', value: 'Honda' },
        { op: 'literal', value: 'BMW' },
        { op: 'ref', name: 'test' }
      ]}

    tests.expressionCountIs(4)
    tests.simplifiedExpressionIs({ op: 'concat', operands: [{ op: 'literal', value: 'HondaBMW' }, { op: 'ref', name: 'test' } ]})

  describe 'with ref values 2', ->
    beforeEach ->
      this.expression = { op: 'concat', operands: [
        { op: 'ref', name: 'test2' },
        { op: 'literal', value: 'Honda' },
        { op: 'literal', value: 'BMW' },
        { op: 'ref', name: 'test' }
      ]}

    tests.expressionCountIs(5)
    tests.simplifiedExpressionIs({ op: 'concat', operands: [
      { op: 'ref', name: 'test2' }
      { op: 'literal', value: 'HondaBMW' },
      { op: 'ref', name: 'test' }
    ]})
