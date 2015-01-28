{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'IsExpression', ->
  describe 'IsExpression', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })
    tests.complexityIs(3)
  describe 'IsExpression with reference', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })
    tests.complexityIs(3)
  tests.complexityIs()
