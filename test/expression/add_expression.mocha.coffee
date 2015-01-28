{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'AddExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'add', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] })

  sharedTest(4)
