{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './shared_test'

describe 'OrExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'or', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] })

  sharedTest(4)
