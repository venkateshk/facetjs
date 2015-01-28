{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Expression } = require('../../../build/expression')

sharedTest = require './../shared_test'

describe 'ConcatExpression', ->
  beforeEach -> this.expression = Expression.fromJS({ op: 'concat', operands: [{ op: 'literal', value: 'Honda' }, { op: 'literal', value: 'BMW' }, { op: 'literal', value: 'Suzuki' } ]})

  sharedTest(4)
