{ expect } = require("chai")

tests = require './sharedTests'
describe 'RefExpression', ->
  describe "errors", ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'lol', type: 'toString' }

    tests.errorsFromJS("unsupported type 'toString'")

  describe 'RefExpression with categorical set', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'authors' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'authors'})

  describe 'RefExpression with time range', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'flight_time' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'flight_time'})

  describe 'RefExpression with boolean', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'is_robot' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'is_robot'})

  describe 'RefExpression with number', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'revenue' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'revenue'})

  describe 'RefExpression with numerical range', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'revenue_range' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'revenue_range'})

  describe 'RefExpression with time', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'timestamp' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'timestamp'})

  describe 'RefExpression with STRING', ->
    beforeEach ->
      this.expression = { op: 'ref', type: 'STRING', name: 'make' }

    tests.expressionCountIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'make', type: 'STRING'})
