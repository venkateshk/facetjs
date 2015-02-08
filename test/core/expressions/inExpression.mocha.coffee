{ expect } = require("chai")

tests = require './sharedTests'

describe 'InExpression', ->
  describe 'with category', ->
    beforeEach ->
      this.expression = { op: 'in', lhs: { op: 'literal', value: 'Honda' }, rhs: { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: [0.05, 0.1] }}

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })

  describe 'with reference', ->
    beforeEach ->
      this.expression = { op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'test' }}

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'test' }})

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'in', lhs: { op: 'is', lhs: 1, rhs: 2 }, rhs: { op: 'literal', value: [true] }}

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })
