{ expect } = require("chai")

tests = require './sharedTests'

describe 'MatchExpression', ->
  beforeEach ->
    this.expression = { op: 'match', regexp: '^\d+', operand: { op: 'literal', value: 'Honda' } }

  tests.complexityIs(2)
