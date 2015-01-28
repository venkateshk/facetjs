{ expect } = require("chai")

tests = require './sharedTests'

describe 'AndExpression', ->
  beforeEach ->
    this.expression = { op: 'and', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] }

  tests.complexityIs(4)
