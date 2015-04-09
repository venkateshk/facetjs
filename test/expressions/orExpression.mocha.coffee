{ expect } = require("chai")

facet = require('../../build/facet')
{ Set } = facet

tests = require './sharedTests'

describe 'OrExpression', ->
  describe 'empty expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [] }

    tests.complexityIs(1)
    tests.simplifiedExpressionIs({op: 'literal', value: false})

  describe 'with false expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'literal', value: false },
        { op: 'literal', value: false }
      ] }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({op: 'literal', value: false})

  describe 'with boolean expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'literal', value: true },
        { op: 'literal', value: false },
        { op: 'literal', value: false }
      ] }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({op: 'literal', value: true})

  describe 'with IS expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'is', lhs: "$test", rhs: "blah" },
        { op: 'is', lhs: "$test", rhs: "test2" },
      ] }

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({
      op: 'in',
      lhs: { op: 'ref', name: 'test' },
      rhs: {
        op: 'literal'
        value: { elements: ["blah", "test2"], setType: 'STRING' }
        type: 'SET'
      }
    })

  describe 'with is/in expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'is', lhs: "$test", rhs: "blah3" },
        {
          op: 'in',
          lhs: "$test",
          rhs: {
            op: 'literal'
            value: Set.fromJS(["blah", "test2"])
          }
        }
      ] }

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({
      op: 'in',
      lhs: { op: 'ref', name: 'test' },
      rhs: {
        op: 'literal'
        value: { elements: ["blah", "blah3", "test2"], setType: 'STRING' }
        type: 'SET'
      }
    })

  describe 'with IS/IN expressions 2', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        {
          op: 'in',
          lhs: "$test",
          rhs: {
            op: 'literal'
            value: Set.fromJS(["blah", "test2"])
          }
        }
        { op: 'is', lhs: "$test", rhs: "blah3" }
      ] }

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({
      op: 'in',
      lhs: { op: 'ref', name: 'test' },
      rhs: {
        op: 'literal'
        value: { elements: ["blah", "blah3", "test2"], setType: 'STRING' }
        type: 'SET'
      }
    })

  describe 'with number comparison expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'lessThan', lhs: "$test", rhs: 1 },
        { op: 'lessThanOrEqual', lhs: "$test", rhs: 0 }
      ] }

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({ op: 'lessThan', lhs: { op: 'ref', name: "test" }, rhs: { op: 'literal', value: 1 }})

  describe 'with or expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'or', operands: [{ op: 'lessThan', lhs: "$test1", rhs: 1 }, { op: 'lessThanOrEqual', lhs: "$test2", rhs: 0 }]}
        { op: 'or', operands: [{ op: 'lessThan', lhs: "$test3", rhs: 1 }, { op: 'lessThanOrEqual', lhs: "$test4", rhs: 0 }]}
      ] }

    tests.complexityIs(15)
    tests.simplifiedExpressionIs({ op: 'or', operands: [
      { op: 'lessThan', lhs: { op: 'ref', name: "test1" }, rhs: { op: 'literal', value: 1 }}
      { op: 'lessThanOrEqual', lhs: { op: 'ref', name: "test2" }, rhs: { op: 'literal', value: 0 }}
      { op: 'lessThan', lhs: { op: 'ref', name: "test3" }, rhs: { op: 'literal', value: 1 }}
      { op: 'lessThanOrEqual', lhs: { op: 'ref', name: "test4" }, rhs: { op: 'literal', value: 0 }}
    ] })

  describe 'with irreducible expressions', ->
    beforeEach ->
      this.expression = { op: 'or', operands: [
        { op: 'lessThan', lhs: "$test", rhs: 1 },
        { op: 'lessThan', lhs: 2, rhs: "$test" }
      ] }

    tests.complexityIs(7)
    tests.simplifiedExpressionIs({
      op: 'or',
      operands: [
        {
          op: 'lessThan'
          lhs: { op: 'ref', name: 'test' }
          rhs: { op: 'literal', value: 1 }
        },
        {
          op: 'lessThan'
          lhs: { op: 'literal', value: 2 }
          rhs: { op: 'ref', name: 'test' }
        }
      ]
    })
