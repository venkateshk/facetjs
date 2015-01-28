{ expect } = require("chai")

tests = require './sharedTests'

describe 'LessThanOrEqualExpression', ->
  beforeEach ->
    this.expression = { op: 'lessThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }

  tests.complexityIs(3)
