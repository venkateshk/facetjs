{ expect } = require("chai")


sharedTest = require './shared_test'

describe 'RangeExpression with number', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })
  tests.complexityIs(1)
