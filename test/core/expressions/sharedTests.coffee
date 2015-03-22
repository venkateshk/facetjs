{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ Expression } = facet.core


exports.errorsFromJS = (expectedMessage) ->
  it "throws #{expectedMessage} error correctly during fromJS", ->
    expression = @expression
    expect(->
      Expression.fromJS(expression)
    ).to.throw(expectedMessage)


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
