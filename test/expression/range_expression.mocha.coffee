{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'


describe 'RangeExpression with number', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } })

  sharedTest(1)
