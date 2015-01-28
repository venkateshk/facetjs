{ expect } = require("chai")


tests = require './sharedTests'
describe 'OrExpression', ->
  beforeEach ->
    this.expression = { op: 'or', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] }
  tests.complexityIs(4)
