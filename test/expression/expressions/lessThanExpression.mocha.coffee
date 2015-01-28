{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './shared_test'

describe 'LessThanExpression', ->
  describe 'LessThanExpression', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    sharedTest(3)

  describe 'LessThanExpression with reference', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    sharedTest(3)
