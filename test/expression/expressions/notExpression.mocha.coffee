{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'NotExpression', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'not', operand: { op: 'literal', value: true } })
  tests.complexityIs(2)
