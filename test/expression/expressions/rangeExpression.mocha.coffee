{ expect } = require("chai")

tests = require './sharedTests'

describe 'RangeExpression with number', ->
  beforeEach ->
    this.expression = { op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

  tests.complexityIs(3)
