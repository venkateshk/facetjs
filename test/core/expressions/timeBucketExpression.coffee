tests = require './sharedTests'

describe 'TimeBucketExpression', ->
  describe 'with simple expression', ->
    beforeEach ->
      this.expression = {
        op: 'timeBucket',
        operand: {
          op: 'literal'
          value: new Date(10)
        }
        duration: 'P1D'
      }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({
      op: 'timeBucket',
      operand: {
        op: 'literal'
        value: new Date(10)
      }
      duration: 'P1D'
    })
