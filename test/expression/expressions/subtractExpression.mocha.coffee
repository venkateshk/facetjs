{ expect } = require("chai")

tests = require './sharedTests'

describe 'SubtractExpression', ->
  describe 'with only literal values', ->
    beforeEach ->
      this.expression = { op: 'subtract', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({
      op: 'literal'
      value: 16.6
    })

  describe 'with one ref value', ->
    beforeEach ->
      this.expression = { op: 'subtract', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'subtract', operands: [{ op: 'ref', name: 'test' }, { op: 'literal', value: -11.6 }] })


  describe 'with one ref value 2', ->
    beforeEach ->
      this.expression = { op: 'subtract', operands: [{ op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }, { op: 'ref', name: 'test' }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'subtract', operands: [{ op: 'literal', value: -12.4 }, { op: 'ref', name: 'test' }] })

  describe 'with 2 ref values', ->
    beforeEach ->
      this.expression = { op: 'subtract', operands: [{ op: 'ref', name: 'test1' }, { op: 'literal', value: 0.4 }, { op: 'ref', name: 'test2' }] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({ op: 'subtract', operands: [{ op: 'ref', name: 'test1' }, { op: 'ref', name: 'test2' }, { op: 'literal', value: 0.4 }] })
