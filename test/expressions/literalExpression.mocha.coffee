facet = require('../../build/facet')
{ Set, NumberRange, $ } = facet

tests = require './sharedTests'

describe 'LiteralExpression', ->
  describe 'with boolean', ->
    beforeEach ->
      this.expression = { op: 'literal', value: true }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with string', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 'Honda' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 'Honda' })

  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 6 }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 6 })

  describe 'with set (js)', ->
    beforeEach ->
      this.expression = { op: 'literal', value: { elements: ['Honda', 'BMW', 'Suzuki'] }, type: "SET" }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: { elements: ['BMW', 'Honda', 'Suzuki'], setType: "STRING" }, type: "SET" })

  describe 'with set (higher object)', ->
    beforeEach ->
      this.expression = { op: 'literal', value: Set.fromJS({ elements: ['Honda', 'BMW', 'Suzuki'] }) }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: { elements: ['BMW', 'Honda', 'Suzuki'], setType: "STRING" }, type: "SET" })

  describe 'with numerical range', ->
    beforeEach ->
      this.expression = { op: 'literal', value: NumberRange.fromJS({start: 0.05, end: 0.1}) }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: {start: 0.05, end: 0.1}, type: "NUMBER_RANGE" })

  describe 'with null', ->
    beforeEach ->
      this.expression = { op: 'literal', value: null }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: null })

