{ expect } = require("chai")

tests = require './sharedTests'

describe 'AddExpression', ->
  describe 'AddExpression with only literal values', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({
      op: 'literal'
      value: -6.6
    })

  describe 'AddExpression with ref values', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -11.6 }] })