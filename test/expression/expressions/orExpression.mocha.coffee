{ expect } = require("chai")


sharedTest = require './shared_test'
describe 'OrExpression', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'or', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] })
  tests.complexityIs(4)
