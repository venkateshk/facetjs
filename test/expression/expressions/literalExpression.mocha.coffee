{ expect } = require("chai")

tests = require './sharedTests'

describe 'LiteralExpression', ->
  describe 'LiteralExpression with boolean', ->
    beforeEach ->
      this.expression = { op: 'literal', value: true }

    tests.complexityIs(1)

  describe 'LiteralExpression with category', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 'Honda' }

    tests.complexityIs(1)

  describe 'LiteralExpression with number', ->
    beforeEach ->
      this.expression = { op: 'literal', value: 6 }

    tests.complexityIs(1)

  describe 'LiteralExpression with categorical set', ->
    beforeEach ->
      this.expression = { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] }

    tests.complexityIs(1)

  describe 'LiteralExpression with numerical range', ->
    beforeEach ->
      this.expression = { op: 'literal', value: [0.05, 0.1] }

    tests.complexityIs(1)

  describe 'LiteralExpression with categorical set', ->
    beforeEach ->
      this.expression = { op: 'literal', value: null }

    tests.complexityIs(1)

