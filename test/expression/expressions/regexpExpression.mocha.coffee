{ expect } = require("chai")


tests = require './sharedTests'
describe 'RegexpExpression', ->
  beforeEach ->
    this.expression = { op: 'regexp', regexp: '^\d+', operand: { op: 'literal', value: 'Honda' } }
  tests.complexityIs(2)
