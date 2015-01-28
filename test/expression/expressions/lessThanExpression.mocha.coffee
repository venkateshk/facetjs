{ expect } = require("chai")

tests = require './sharedTests'

describe 'LessThanExpression', ->
  describe 'LessThanExpression', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)

  describe 'LessThanExpression with reference', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
