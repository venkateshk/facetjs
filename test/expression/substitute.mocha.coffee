{ expect } = require("chai")

facet = require('../../build/facet')
{ Expression } = facet.Module

describe "substitute", ->
  it "should substitute on IS", ->
    ex = Expression.fromJS({
      op: 'is'
      lhs: 5
      rhs: '$hello'
    })

    subs = (ex) ->
      if ex.op is 'literal' and ex.type is 'NUMBER'
        return Expression.fromJSLoose(ex.value + 10)
      else
        return null

    expect(ex.substitute(subs).toJS()).to.deep.equal({
      "lhs": {
        "op": "literal"
        "value": 15
      }
      "op": "is"
      "rhs": {
        "name": "hello"
        "op": "ref"
      }
    })


