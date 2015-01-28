{ expect } = require("chai")

sharedTest = require './shared_test'

describe 'GreaterThanExpression', ->
  describe 'GreaterThanExpression', ->
    beforeEach ->
      this.expression = Expression.fromJS({ op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    tests.complexityIs(3)

  describe 'GreaterThanExpression with reference', ->
    beforeEach ->
      this.expression = Expression.fromJS({ op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })

    tests.complexityIs(3)
