{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

sharedTest = require './shared_test'

describe 'RefExpression', ->
  describe 'RefExpression with categorical set', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'authors' })

    sharedTest(1)

  describe 'RefExpression with time range', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'flight_time' })

    sharedTest(1)

  describe 'RefExpression with boolean', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'is_robot' })

    sharedTest(1)

  describe 'RefExpression with number', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'revenue' })

    sharedTest(1)

  describe 'RefExpression with numberical range', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'revenue_range' })

    sharedTest(1)

  describe 'RefExpression with time', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', name: 'timestamp' })

    sharedTest(1)

  describe 'RefExpression with category', ->
    beforeEach -> this.expression = Expression.fromJS({ op: 'ref', type: 'categorical', name: 'make' })

    sharedTest(1)
