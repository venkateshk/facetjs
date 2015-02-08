tests = require './sharedTests'

describe 'TimeRangeExpression', ->
  describe 'with number', ->
    beforeEach ->
      this.expression = { op: 'timeRange', lhs: { op: 'literal', value: new Date(5) }, rhs: { op: 'literal', value: new Date(7) } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'literal', value: {start: new Date(5), end: new Date(7)}, type: 'TIME_RANGE' })

  describe 'with ref', ->
    beforeEach ->
      this.expression = { op: 'timeRange', lhs: { op: 'literal', value:  new Date(5) }, rhs: { op: 'ref', name: 'blah' } }

    tests.complexityIs(3)
    tests.simplifiedExpressionIs({ op: 'timeRange', lhs: { op: 'literal', value:  new Date(5) }, rhs: { op: 'ref', name: 'blah' } })
