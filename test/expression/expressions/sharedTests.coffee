{ expect } = require("chai")

{ Expression } = require('../../../build/expression')

exports.complexityIs = (expectedComplexity) ->
  it '#getComplexty() gets the complexity correctly', ->
    expect(Expression.fromJS(@expression).getComplexity()).to.equal(expectedComplexity)
