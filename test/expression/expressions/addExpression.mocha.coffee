{ expect } = require("chai")

tests = require './sharedTests'

describe 'AddExpression', ->
  describe 'with only literal values', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({
      op: 'literal'
      value: -6.6
    })

  describe 'with one ref value', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -11.6 }] })

  describe 'with two ref values', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }, { op: 'ref', name: 'test2' }] }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({ op: 'add', operands: [{ op: 'ref', name: 'test' }, { op: 'ref', name: 'test2' }, { op: 'literal', value: -11.6 }] })


  describe 'with no values', ->
    beforeEach ->
      this.expression = { op: 'add', operands: [] }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 0 })
