{ expect } = require("chai")


tests = require './sharedTests'

describe 'DivideExpression', ->
  beforeEach ->
    this.expression = { op: 'divide', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
  tests.complexityIs(4)
