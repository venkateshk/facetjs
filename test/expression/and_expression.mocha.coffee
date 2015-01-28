{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'AndExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'and', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] })

  sharedTest(4)
