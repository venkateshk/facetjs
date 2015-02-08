{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Set } = facet.Core

tests = require './sharedTests'

describe 'IsExpression', ->
  describe 'with true value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with false value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 2 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: false })

  describe 'with string value', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: 'abc', rhs: 'abc' }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })

  describe 'with reference', ->
    describe 'in NUMBER type', ->
      beforeEach ->
        this.expression = { op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 5 } }

      tests.complexityIs(3)
      tests.simplifiedExpressionIs({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 5 } })

      describe '#mergeAnd', ->
        tests
          .mergedAndWith(
            "with a different IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: 7 }
            }
          )
          .equals({ op: 'literal', value: false })

        tests
          .mergedAndWith(
            "with the same IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: 5 }
            }
          )
          .equals({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 5 }})

        tests
          .mergedAndWith(
            "with inclusive InExpression",
            {
              op: 'in',
              lhs: { op: 'ref', name: 'flight_time', type: 'NUMBER' },
              rhs: { op: 'numberRange', lhs: 5, rhs: 7, type: 'NUMBER_RANGE' }
            }
          )
          .equals({
            op: 'in'
            lhs: { op: 'ref', name: 'flight_time', type: 'NUMBER' }
            rhs: {
              op: 'numberRange'
              lhs: { op: 'literal', value: 5 }
              rhs: { op: 'literal', value: 7 }
            }
          })


    describe 'in Time type', ->
      beforeEach ->
        this.expression = { op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: new Date(6) } }

      tests.complexityIs(3)
      tests.simplifiedExpressionIs({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: new Date(6) } })

      describe '#mergeAnd', ->
        tests
          .mergedAndWith(
            "with a different IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: new Date(2) }
            }
          )
          .equals({ op: 'literal', value: false })

        tests
          .mergedAndWith(
            "with the same IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: new Date(6) }
            }
          )
          .equals({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: new Date(6) }})

        tests
          .mergedAndWith(
            "with inclusive InExpression",
            {
              op: 'in'
              lhs: { op: 'ref', name: 'flight_time', type: 'TIME' }
              rhs: {
                op: 'timeRange'
                lhs: { op: 'literal', value: new Date(0), type: 'TIME' }
                rhs: { op: 'literal', value: new Date(7), type: 'TIME' }
              }
            }
          )
          .equals({
            op: 'in'
            lhs: { op: 'ref', name: 'flight_time', type: 'TIME' }
            rhs: {
              op: 'timeRange'
              lhs: { op: 'literal', value: new Date(0) }
              rhs: { op: 'literal', value: new Date(7) }
            }
          })

    describe 'in STRING type', ->
      beforeEach ->
        this.expression = { op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 'ABC' } }

      tests.complexityIs(3)
      tests.simplifiedExpressionIs({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 'ABC' } })

      describe '#mergeAnd', ->
        tests
          .mergedAndWith(
            "with a different IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: 'BCD' }
            }
          )
          .equals({ op: 'literal', value: false })

        tests
          .mergedAndWith(
            "with the same IsExpression",
            {
              op: 'is',
              lhs: { op: 'ref', name: 'flight_time' },
              rhs: { op: 'literal', value: 'ABC' }
            }
          )
          .equals({ op: 'is', lhs: { op: 'ref', name: 'flight_time' }, rhs: { op: 'literal', value: 'ABC' }})

        tests
          .mergedAndWith(
            "with inclusive InExpression",
            {
              op: 'in',
              lhs: { op: 'ref', name: 'flight_time', type: 'STRING' },
              rhs: { op: 'literal', value: Set.fromJS({values: ['ABC', 'DEF']}) }
            }
          )
          .equals({
            op: 'in'
            lhs: { op: 'ref', name: 'flight_time', type: 'STRING' }
            rhs: { op: 'literal', value: {values: ['ABC', 'DEF']}, type: 'SET' }
          })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'is', lhs: { op: 'is', lhs: 1, rhs: 2 }, rhs: { op: 'is', lhs: 5, rhs: 2 }}

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({ op: 'literal', value: true })
