{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'RegexpExpression', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'regexp', regexp: '^\d+', operand: { op: 'literal', value: 'Honda' } })
  tests.complexityIs(2)
