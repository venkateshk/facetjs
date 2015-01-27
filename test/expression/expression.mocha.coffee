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
        op: 'ref'
        name: 'hello'
      }
      {
        op: 'ref'
        name: 'goodbye'
      }
      {
        op: 'is'
        lhs: { op: 'ref', name: 'hello' }
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
        lhs: { op: 'ref', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'lessThanOrEqual'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'lessThanOrEqual'
        lhs: { op: 'ref', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'greaterThan'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'greaterThan'
        lhs: { op: 'ref', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }
      {
        op: 'greaterThanOrEqual'
        lhs: { op: 'literal', value: 5 }
        rhs: { op: 'literal', value: 8 }
      }
      {
        op: 'greaterThanOrEqual'
        lhs: { op: 'ref', name: 'x' }
        rhs: { op: 'literal', value: 5 }
      }

      {
        op: 'actions'
        operand: { op: 'ref', name: 'diamonds' }
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
          lhs: { op: 'ref', name: 'hello' }
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


  describe.skip "#getFn", ->
    it "works in a simple case of IS", ->
      ex = Expression.fromJS({
        op: 'is'
        lhs: { op: 'ref', name: x }
        rhs: { op: 'literal', value: 8 }
      })
      exFn = ex.getFn()
      expect(exFn({x: 5})).to.equal(false)
      expect(exFn({x: 8})).to.equal(false)

    it "works in a simple case of addition", ->
      ex = Expression.fromJS({
        op: 'addition'
        operands: [
          { op: 'ref', name: x }
          { op: 'ref', name: y }
          { op: 'literal', value: 5 }
        ]
      })
      exFn = ex.getFn()
      expect(exFn({x: 5, y: 1})).to.equal(11)
      expect(exFn({x: 8, y: -3})).to.equal(10)


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

