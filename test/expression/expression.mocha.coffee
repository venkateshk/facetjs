{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../build/expression')

# TODO: Make these as test cases too
# describe 'LiteralExpression with dataset', -> beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: <Dataset> })
# describe 'LiteralExpression with time', -> beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: Time })
# describe 'LiteralExpression with time range', -> beforeEach -> this.expression = Expression.fromJS({ op: 'literal', value: { start: ..., end: ...} })
# describe 'InExpression with time', -> beforeEach -> this.expression = Expression.fromJS({ op: 'in', lhs: TIME, rhs: TIME_RANGE })
# describe 'AggregateExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'aggregate', operand: DATASET, aggregate: 'sum', attribute: EXPRESSION })
# describe 'OffsetExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'offset', operand: TIME, offset: 'P1D' })
# describe 'BucketExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'bucket', operand: NUMERIC, size: 0.05, offset: 0.01 })
# describe 'BucketExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'bucket', operand: TIME, duration: 'P1D' })
# describe 'RangeExpression with time', -> beforeEach -> this.expression = Expression.fromJS({ op: 'range', lhs: TIME, rhs: TIME })
# describe 'SplitExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'split', operand: DATASET, attribute: EXPRESSION, name: 'splits' })

# describe 'MaxExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'max', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] })
# describe 'MinExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'min', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] })
# describe 'AlternativeExpression', -> beforeEach -> this.expression = Expression.fromJS({ op: 'alternative', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] })


describe "Expression", ->
  it "passes higher object tests", ->
    testHigherObjects(Expression, [
      { op: 'literal', value: true }
      { op: 'literal', value: 'Honda' }
      { op: 'literal', value: 6 }
      #{ op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] }
      #{ op: 'literal', value: [0.05, 0.1] }
      { op: 'literal', value: null }
      { op: 'ref', name: 'authors' }
      { op: 'ref', name: 'flight_time' }
      { op: 'ref', name: 'is_robot' }
      { op: 'ref', name: 'revenue' }
      { op: 'ref', name: 'revenue_range' }
      { op: 'ref', name: 'timestamp' }
      #{ op: 'ref', type: 'categorical', name: 'make' }
      { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'is', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
      { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'lessThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'lessThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
      { op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'greaterThan', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
      { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'greaterThanOrEqual', lhs: { op: 'literal', value: 5 }, rhs: { op: 'ref', name: 'flight_time' } }
      #{ op: 'in', lhs: { op: 'literal', value: 'Honda' }, rhs: { op: 'literal', value: ['Honda', 'BMW', 'Suzuki'] } }
      #{ op: 'in', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: [0.05, 0.1] } }
      { op: 'match', regexp: '^\d+', operand: { op: 'literal', value: 'Honda' } }
      { op: 'not', operand: { op: 'literal', value: true } }
      { op: 'and', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] }
      { op: 'or', operands: [{ op: 'literal', value: true }, { op: 'literal', value: false }, { op: 'literal', value: false }] }
      { op: 'add', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
      { op: 'subtract', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
      { op: 'multiply', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
      { op: 'divide', operands: [{ op: 'literal', value: 5 }, { op: 'literal', value: -12 }, { op: 'literal', value: 0.4 }] }
      { op: 'concat', operands: [{ op: 'literal', value: 'Honda' }, { op: 'literal', value: 'BMW' }, { op: 'literal', value: 'Suzuki' } ]}
      { op: 'range', lhs: { op: 'literal', value: 5 }, rhs: { op: 'literal', value: 5 } }
      { op: 'actions', operand: { op: 'ref', name: 'diamonds' }, actions: [ { action: 'apply', name: 'five', expression: { op: 'literal', value: 5 } } ] }
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

