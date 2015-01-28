{ expect } = require("chai")


tests = require './sharedTests'
describe 'MultiplyExpression', ->
  beforeEach ->
    this.expression = { op: 'multiply', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
  tests.complexityIs(4)
