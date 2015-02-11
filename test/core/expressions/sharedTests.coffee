{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression } = facet.core

exports.complexityIs = (expectedComplexity) ->
  it '#getComplexty() gets the complexity correctly', ->
    expect(Expression.fromJS(@expression).getComplexity()).to.equal(expectedComplexity)

exports.simplifiedExpressionIs = (expectedSimplifiedExpression) ->
  it '#simplify() returns the correct simplified expression', ->
    expect(Expression.fromJS(@expression).simplify().toJS()).to.deep.equal(expectedSimplifiedExpression)

exports.mergeAndWith = (testCaseTitle, mergingExpression) ->
  return {
    equals: (expectedExpression) ->
      it testCaseTitle, ->
        mergedExp = Expression.fromJS(@expression).mergeAnd(Expression.fromJS(mergingExpression))
        expect(
          if mergedExp? then mergedExp.toJS() else null
        ).to.deep.equal(expectedExpression)
  }

exports.mergeOrWith = (testCaseTitle, mergingExpression) ->
  return {
  equals: (expectedExpression) ->
    it testCaseTitle, ->
      mergedExp = Expression.fromJS(@expression).mergeOr(Expression.fromJS(mergingExpression))
      expect(
        if mergedExp? then mergedExp.toJS() else null
      ).to.deep.equal(expectedExpression)
  }
