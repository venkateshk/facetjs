{ expect } = require("chai")

tests = require './sharedTests'

describe 'ActionsExpression', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'actions', operand: { op: 'ref', name: 'diamonds' }, actions: [ { action: 'def', name: 'five', expression: { op: 'literal', value: 5 } } ] })

  tests.complexityIs(2)
