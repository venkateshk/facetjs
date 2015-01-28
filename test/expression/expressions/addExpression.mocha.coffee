{ expect } = require("chai")

tests = require './sharedTests'

describe 'AddExpression', ->
  beforeEach ->
    this.expression = { op: 'add', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }

  tests.complexityIs(4)
