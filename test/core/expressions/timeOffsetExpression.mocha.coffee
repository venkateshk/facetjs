tests = require './sharedTests'

describe 'TimeOffsetExpression', ->
  describe 'with simple expression', ->
    beforeEach ->
      this.expression = {
        op: 'timeOffset',
        operand: {
          op: 'literal'
          value: new Date(10)
        }
        duration: 'P1D'
      }

    tests.complexityIs(2)
#    tests.simplifiedExpressionIs({
#      op: 'timeOffset',
#      operand: {
#        op: 'literal'
#        value: new Date(10)
#      }
#      duration: 'P1D'
#    })
