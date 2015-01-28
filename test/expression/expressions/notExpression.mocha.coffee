{ expect } = require("chai")

tests = require './sharedTests'

describe 'NotExpression', ->
  beforeEach ->
    this.expression = { op: 'not', operand: { op: 'literal', value: true } }

  tests.complexityIs(2)
