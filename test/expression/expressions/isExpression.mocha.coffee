{ expect } = require("chai")


tests = require './sharedTests'
describe 'IsExpression', ->
  describe 'IsExpression', ->
    beforeEach ->
    this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
    tests.complexityIs(3)
  describe 'IsExpression with reference', ->
    beforeEach ->
    this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
    tests.complexityIs(3)
  tests.complexityIs()
