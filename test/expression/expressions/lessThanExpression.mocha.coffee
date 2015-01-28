{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'LessThanExpression', ->
  describe 'LessThanExpression', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })
    tests.complexityIs(3)
  describe 'LessThanExpression with reference', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })
    tests.complexityIs(3)
