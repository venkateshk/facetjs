{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'RegexpExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'regexp', regexp: '^\d+', operand: { op: 'literal', value: 'Honda' } })

  sharedTest(2)
