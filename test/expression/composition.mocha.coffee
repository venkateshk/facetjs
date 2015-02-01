{ expect } = require("chai")

{ Expression } = require('../../build/expression')

describe "composition", ->
  facet = Expression.facet

  it "works in blank case", ->
    ex = facet()
    expect(ex.toJS()).to.deep.equal({
      "op": "literal"
      "type": "DATASET"
      "value": {
        "dataset": "base"
        "data": [{}]
      }
    })

  it "works in ref case", ->
    ex = facet("diamonds")
    expect(ex.toJS()).to.deep.equal({
      "op": "ref"
      "name": "diamonds"
    })

  it "works in uber-basic case", ->
    ex = facet()
      .apply('five', 5)
      .apply('nine', 9)

    expect(ex.toJS()).to.deep.equal({
      "op": "actions"
      "operand": {
        "op": "literal"
        "type": "DATASET"
        "value": {
          "data": [{}]
          "dataset": "base"
        }
      }
      "actions": [
        {
          "action": "apply"
          "name": "five"
          "expression": { "op": "literal", "value": 5 }
        }
        {
          "action": "apply"
          "name": "nine"
          "expression": { "op": "literal", "value": 9 }
        }
      ]
    })

  it "works in semi-realistic case", ->
    someDriver = {} # ToDo: fix this

    ex = facet()
      .apply("Diamonds",
        facet() # someDriver)
          .filter(facet('color').is('D'))
          .apply("priceOver2", facet("price").divide(2))
      )
      .apply('Count', facet('Diamonds').count())
      .apply('TotalPrice', facet('Diamonds').sum('$priceOver2'))

    console.log(ex.toJS())
    expect(ex.toJS()).to.deep.equal({
      "?": "?"
    })

  it.skip "works in semi-realistic case (using parser)", ->
    someDriver = {} # ToDo: fix this

    ex = facet()
      .apply("Diamonds",
        facet(someDriver)
          .filter("$color = 'D'")
          .apply("priceOver2", "$price/2")
      )
      .apply('Count', facet('Diamonds').count())
      .apply('TotalPrice', facet('Diamonds').sum('$priceOver2'))

    console.log(ex.toJS())
    expect(ex.toJS()).to.deep.equal({
      "?": "?"
    })