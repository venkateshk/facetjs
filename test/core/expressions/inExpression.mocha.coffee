{ expect } = require("chai")
{ Set } = require('../../../build/facet').Core

tests = require './sharedTests'

describe 'InExpression', ->
  describe 'with set', ->
    beforeEach ->
      this.expression = {
        op: 'in',
        lhs: { op: 'literal', value: 'Honda' },
        rhs: { op: 'literal', value: Set.fromJS({values: ['Honda', 'BMW', 'Suzuki']}) }
      }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with number range', ->
    beforeEach ->
      this.expression = {
        op: 'in',
        lhs: { op: 'literal', value: 5 },
        rhs: { op: 'numberRange', lhs: 0.05, rhs: 0.1 }
      }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })

  describe 'with invalid number range', ->
    beforeEach ->
      this.expression = {
        op: 'in',
        lhs: { op: 'ref', name: 'test' },
        rhs: { op: 'numberRange', lhs: 0.05, rhs: 0 }
      }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({
      op: 'in',
      lhs: { op: 'ref', name: 'test' },
      rhs: { op: 'literal', value: { start: 0.05, end: 0 }, type: 'NUMBER_RANGE' }
    })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = {
        op: 'in',
        lhs: { op: 'is', lhs: 1, rhs: 2 },
        rhs: { op: 'literal', value: Set.fromJS({values: [true]}) }
      }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })

  describe 'with right-handed reference', ->
    beforeEach ->
      this.expression = {
        op: 'in',
        lhs: { op: 'literal', value: 5 },
        rhs: { op: 'ref', name: 'test' }
      }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'test' }})

  describe 'with left-handed reference', ->
    describe 'with SET', ->
      beforeEach ->
        this.expression = {
          op: 'in',
          lhs: { op: 'ref', name: 'test' },
          rhs: { op: 'literal', value: Set.fromJS({values: ['A']}) }
        }

      tests.complexityIs(3)
      tests.simplifiedExpressionIs({
        op: 'in',
        lhs: { op: 'ref', name: 'test' },
        rhs: { op: 'literal', value: {values: ['A']}, type: 'SET' }
      })

      describe '#mergeAnd', ->
        tests
          .mergeAndWith(
            "with an is expression"
            {
              op: 'is',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: 'A' }
            }
          )
          .equals(
            {
              op: 'is',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: 'A' }
            }
          )

        tests
          .mergeAndWith(
            "with a disjoint set"
            {
              op: 'in',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: Set.fromJS({values: ['B', 'C']}) }
            }
          )
          .equals(
            {
              op: 'in',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: {values: []}, type: 'SET' }
            }
          )

        tests
          .mergeAndWith(
            "with an intersecting set"
            {
              op: 'in',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: Set.fromJS({values: ['A', 'B', 'C']}) }
            }
          )
          .equals(
            {
              op: 'in',
              lhs: { op: 'ref', name: 'test' },
              rhs: { op: 'literal', value: {values: ['A']}, type: 'SET' }
            }
          )
