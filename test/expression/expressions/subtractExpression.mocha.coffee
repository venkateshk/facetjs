{ expect } = require("chai")


sharedTest = require './shared_test'

describe 'SubtractExpression', ->
  beforeEach ->
    this.expression = Expression.fromJS({ op: 'subtract', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] })
  tests.complexityIs(4)
