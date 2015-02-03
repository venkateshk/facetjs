{ expect } = require("chai")

{ Expression } = require('../../build/expression')

describe "substitute", ->
  it "should substitute on unbalanced IS", ->
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
        "type": "NUMBER"
        "value": 15
      }
      "op": "is"
      "rhs": {
        "name": "hello"
        "op": "ref"
      }
      "type": "BOOLEAN"
    })


