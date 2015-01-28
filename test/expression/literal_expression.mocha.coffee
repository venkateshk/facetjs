{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'LiteralExpression', ->
  describe 'LiteralExpression with boolean', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: true })

    sharedTest(1)

  describe 'LiteralExpression with category', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: 'Honda' })

    sharedTest(1)

  describe 'LiteralExpression with number', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: 6 })

    sharedTest(1)

  describe 'LiteralExpression with categorical set', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] })

    sharedTest(1)

  describe 'LiteralExpression with numerical range', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: [0.05, 0.1] })

    sharedTest(1)

  describe 'LiteralExpression with categorical set', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: null })

    sharedTest(1)
