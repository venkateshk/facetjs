tests = require './sharedTests'

describe 'NumberBucketExpression', ->
  describe 'with simple expression', ->
    beforeEach ->
      this.expression = {
        op: 'numberBucket'
        operand: { op: 'literal', value: 1 }
        size: 0.05
        offset: 1
      }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({
      op: 'numberBucket'
      operand: { op: 'literal', value: 1 }
      size: 0.05
      offset: 1
    })

  describe 'with complex expression', ->
    beforeEach ->
      this.expression = {
        op: 'numberBucket'
        operand: {
          op: 'multiply',
          operands: [
            { op: 'literal', value: 1 }
            { op: 'literal', value: 4 }
          ]
        }
        size: 0.05
        offset: 1
      }

    tests.complexityIs(4)
    tests.simplifiedExpressionIs({
      op: 'numberBucket'
      operand: { op: 'literal', value: 4 }
      size: 0.05
      offset: 1
    })
