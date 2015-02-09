{ expect } = require("chai")

tests = require './sharedTests'

describe 'LessThanExpression', ->
  describe 'with false literal values', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: false})

  describe 'with true literal values', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 7 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op:'literal', value: true})

  describe 'with left-handed reference', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'ref', name: 'test' }, rhs: { op: 'literal', value: 5 } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'lessThan', lhs: { op: 'ref', name: 'test' }, rhs: { op: 'literal', value: 5 } })

    describe '#mergeAnd', ->
      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of smaller value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 1
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 1 }
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of equal value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 5
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 5 }
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of larger value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 7
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 5 }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of smaller value",
          {
            op: 'lessThan',
            lhs: 1,
            rhs: "$test"
          })
        .equals(null)

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of equal value",
          {
            op: 'lessThan',
            lhs: 5,
            rhs: "$test"
          })
        .equals({
            op: 'literal',
            value: false
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of larger value",
          {
            op: 'lessThan',
            lhs: 7,
            rhs: "$test"
          })
        .equals({
            op: 'literal',
            value: false
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of smaller value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 1
          })
        .equals({
            op: 'lessThanOrEqual',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 1 }
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of equal value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 5
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 5 }
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of larger value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 7
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'ref', name: 'test' }
            rhs: { op: 'literal', value: 5 }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of smaller value",
          {
            op: 'lessThanOrEqual',
            lhs: 1,
            rhs: "$test"
          })
        .equals({
            "op": "in",
            "lhs": {
              "op": "ref",
              "name": "test"
            },
            "rhs": {
              "op": "numberRange",
              "lhs": {
                "op": "literal",
                "value": 1
              },
              "rhs": {
                "op": "literal",
                "value": 5
              }
            }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of equal value",
          {
            op: 'lessThanOrEqual',
            lhs: 5,
            rhs: "$test"
          })
        .equals({
            op: 'literal',
            value: false
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of larger value",
          {
            op: 'lessThanOrEqual',
            lhs: 7,
            rhs: "$test"
          })
        .equals({
            op: 'literal',
            value: false
          })

  describe 'with right-handed reference', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'test' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'test' } })

    describe '#mergeAnd', ->
      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of smaller value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 1
          })
        .equals({
            op: 'literal',
            value: false
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of equal value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 5
          })
        .equals(null)

      tests
        .mergeAndWith(
          "merges with left-handed lessThan expression of larger value",
          {
            op: 'lessThan',
            lhs: "$test",
            rhs: 7
          })
        .equals(null)

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of smaller value",
          {
            op: 'lessThan',
            lhs: 1,
            rhs: "$test"
          })
        .equals({
          op: 'lessThan',
          lhs: { op: 'literal', value: 5 },
          rhs: { op: 'ref', name: 'test' }
        })

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of equal value",
          {
            op: 'lessThan',
            lhs: 5,
            rhs: "$test"
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'literal', value: 5 },
            rhs: { op: 'ref', name: 'test' }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThan expression of larger value",
          {
            op: 'lessThan',
            lhs: 7,
            rhs: "$test"
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'literal', value: 7 },
            rhs: { op: 'ref', name: 'test' }
          })


      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of smaller value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 1
          })
        .equals({
            op:'literal',
            value: false
          })

      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of equal value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 5
          })
        .equals(null)

      tests
        .mergeAndWith(
          "merges with left-handed lessThanOrEqual expression of larger value",
          {
            op: 'lessThanOrEqual',
            lhs: "$test",
            rhs: 7
          })
        .equals(null)

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of smaller value",
          {
            op: 'lessThanOrEqual',
            lhs: 1,
            rhs: "$test"
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'literal', value: 5 },
            rhs: { op: 'ref', name: 'test' }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of equal value",
          {
            op: 'lessThanOrEqual',
            lhs: 5,
            rhs: "$test"
          })
        .equals({
            op: 'lessThan',
            lhs: { op: 'literal', value: 5 },
            rhs: { op: 'ref', name: 'test' }
          })

      tests
        .mergeAndWith(
          "merges with right-handed lessThanOrEqual expression of larger value",
          {
            op: 'lessThanOrEqual',
            lhs: 7,
            rhs: "$test"
          })
        .equals({
            op: 'lessThanOrEqual',
            lhs: { op: 'literal', value: 7 },
            rhs: { op: 'ref', name: 'test' }
          })

  describe 'with complex values', ->
    beforeEach ->
      this.expression = { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'add', operands: [{ op: 'literal', value: 3 }, { op: 'literal', value: 3 }] } }

    tests.complexityIs(5)
    tests.simplifiedExpressionIs({op:'literal', value: true})
