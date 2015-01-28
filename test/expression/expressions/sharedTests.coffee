{ expect } = require("chai")

{ Expression } = require('../../../build/expression')

exports.complexityIs = (expectedComplexity) ->
  it '#getComplexty() gets the complexity correctly', ->
    expect(Expression.fromJS(@expression).getComplexity()).to.equal(expectedComplexity)

exports.simplifiedExpressionIs = (expectedSimplifiedExpression) ->
  it '#simplify() returns the correct simplified expression', ->
    expect(Expression.fromJS(@expression).simplify().toJS()).to.deep.equal(expectedSimplifiedExpression)
