{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

describe "Expression", ->
  it "passes higher object tests", ->

    testHigherObjects(Expression, [
      {
        op: 'literal'
        value: 5
      }
      {
        op: 'literal'
        value: 'facet'
      }
      {
        op: 'lookup'
        name: 'hello'
      }
      {
        op: 'lookup'
        name: 'goodbye'
      }
      {
        op: 'is'
        lhs: { op: 'lookup', name: 'hello' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'is'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'lessThan'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'lessThan'
        lhs: { op: 'lookup', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'lessThanOrEqual'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'lessThanOrEqual'
        lhs: { op: 'lookup', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'greaterThan'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'greaterThan'
        lhs: { op: 'lookup', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'greaterThanOrEqual'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'greaterThanOrEqual'
        lhs: { op: 'lookup', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }

      {
        op: 'actions'
        operand: { op: 'lookup', name: 'diamonds' }
        actions: [
          {
            action: 'def'
            name: 'five'
            expression: { op: 'literal', value: 5 }
          }
        ]
      }
    ], {
      newThrows: true
    })


  describe "errors", ->
    it "does not like an expression without op", ->
      expect(->
        Expression.fromJS({
          lhs: { op: 'lookup', name: 'hello' }
          rhs: { op: 'literal', value: 5 }
        })
      ).to.throw('op must be defined')

    it "does not like an expression with a bad op", ->
      expect(->
        Expression.fromJS({
          op: 42
        })
      ).to.throw('op must be a string')

    it "does not like an expression with a unknown op", ->
      expect(->
        Expression.fromJS({
          op: 'this was once an empty file'
        })
      ).to.throw("unsupported expression op 'this was once an empty file'")

    it "does not like a binary expression without lhs", ->
      expect(->
        Expression.fromJS({
          op: 'is'
          rhs: { op: 'literal', value: 5 }
        })
      ).to.throw('must have a lhs')

    it "does not like a binary expression without rhs", ->
      expect(->
        Expression.fromJS({
          op: 'is'
          lhs: { op: 'literal', value: 5 }
        })
      ).to.throw('must have a rhs')


  describe "#getComplexity", ->
    it "gets the complexity correctly in a simple binary expression", ->
      expect(Expression.fromJS({
        op: 'is'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }).getComplexity()).to.equal(3)

  describe.skip "#simplify", ->
    it "simplifies to literals", ->
      expect(Expression.fromJS({
        op: 'is'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }).simplify().toJS()).to.deep.equal({
        op: 'literal'
        value: false
      })

      expect(Expression.fromJS({
        op: 'is'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 5 }
      }).simplify().toJS()).to.deep.equal({
        op: 'literal'
        value: true
      })

