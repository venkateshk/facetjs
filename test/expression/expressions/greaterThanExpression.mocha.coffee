{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './shared_test'

describe 'GreaterThanExpression', ->
  describe 'GreaterThanExpression', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    sharedTest(3)

  describe 'GreaterThanExpression with reference', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })

    sharedTest(3)
