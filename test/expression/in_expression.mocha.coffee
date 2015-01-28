{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'InExpression', ->
  describe 'InExpression with category', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'in', lhs: { op: 'literal', value: 'Honda' }, rhs: { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] } })

    sharedTest(3)

  describe 'InExpression with number', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: [0.05, 0.1] }})

    sharedTest(3)
