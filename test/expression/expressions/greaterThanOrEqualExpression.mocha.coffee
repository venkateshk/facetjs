{ expect } = require("chai")

tests = require './sharedTests'
describe 'GreaterThanOrEqualExpression', ->
  describe 'GreaterThanOrEqualExpression', ->
    beforeEach ->
    this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
    tests.complexityIs(3)
  describe 'GreaterThanOrEqualExpression with reference', ->
    beforeEach ->
    this.expression = { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
    tests.complexityIs(3)
