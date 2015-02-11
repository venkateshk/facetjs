facet = require('../../../build/facet')
{ Set, NumberRange } = facet.core

tests = require './sharedTests'

describe 'LiteralExpression', ->
  describe 'with boolean', ->
    beforeEach ->
      this.expression = { op: 'literal', value: true }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with string', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 'Honda' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 'Honda' })

  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 6 }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: 6 })

  describe 'with set', ->
    beforeEach ->
      this.expression = { op: 'literal', value: Set.fromJS({values: ['Honda', 'BMW', 'Suzuki']}) }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: {values: ['BMW', 'Honda', 'Suzuki']}, type: "SET" })

  describe 'with numerical range', ->
    beforeEach ->
      this.expression = { op: 'literal', value: NumberRange.fromJS({start: 0.05, end: 0.1}) }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: {start: 0.05, end: 0.1}, type: "NUMBER_RANGE" })

  describe 'with null', ->
    beforeEach ->
      this.expression = { op: 'literal', value: null }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({ op: 'literal', value: null })

