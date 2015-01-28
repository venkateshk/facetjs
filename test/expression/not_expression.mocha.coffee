{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'NotExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'not', operand: { op: 'literal', value: true } })

  sharedTest(2)
