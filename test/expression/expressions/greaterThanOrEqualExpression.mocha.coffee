{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'GreaterThanOrEqualExpression', ->
  describe 'GreaterThanOrEqualExpression', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })
    tests.complexityIs(3)
  describe 'GreaterThanOrEqualExpression with reference', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })
    tests.complexityIs(3)
