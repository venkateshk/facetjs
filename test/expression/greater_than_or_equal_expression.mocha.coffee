{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'GreaterThanOrEqualExpression', ->
  describe 'GreaterThanOrEqualExpression', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    sharedTest(3)

  describe 'GreaterThanOrEqualExpression with reference', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })

    sharedTest(3)
