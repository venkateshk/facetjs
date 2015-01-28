{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'InExpression', ->
  describe 'InExpression with category', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'in', lhs: { op: 'literal', value: 'Honda' }, rhs: { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] } })
    tests.complexityIs(3)
  describe 'InExpression with number', ->
    beforeEach ->
    this.expression = Expression.fromJS({ op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: [0.05, 0.1] }})
    tests.complexityIs(3)
