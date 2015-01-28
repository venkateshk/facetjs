{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './shared_test'

describe 'IsExpression', ->
  describe 'IsExpression', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

    sharedTest(3)

  describe 'IsExpression with reference', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } })

    sharedTest(3)

  sharedTest()
