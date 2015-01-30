{ expect } = require("chai")

tests = require './sharedTests'
describe 'RefExpression', ->

  describe 'RefExpression with categorical set', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'authors' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'authors'})

  describe 'RefExpression with time range', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'flight_time' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'flight_time'})

  describe 'RefExpression with boolean', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'is_robot' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'is_robot'})

  describe 'RefExpression with number', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'revenue' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'revenue'})

  describe 'RefExpression with numberical range', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'revenue_range' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'revenue_range'})

  describe 'RefExpression with time', ->
    beforeEach ->
      this.expression = { op: 'ref', name: 'timestamp' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'timestamp'})

  describe 'RefExpression with category', ->
    beforeEach ->
      this.expression = { op: 'ref', type: 'categorical', name: 'make' }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'ref', name: 'make'})
