{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './../shared_test'

describe 'ActionsExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'actions', operand: { op: 'ref', name: 'diamonds' }, actions: [ { action: 'def', name: 'five', expression: { op: 'literal', value: 5 } } ] })

  sharedTest(2)

