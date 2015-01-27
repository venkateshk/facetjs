{ expect } = require("chai")

{ Expression } = require('../../build/expression')

describe "composition", ->
  facet = Expression.facet

  it "works in blank case", ->
    ex = facet()
    expect(ex.toJS()).to.deep.equal({
      "op": "literal"
      "value": "<Dataset>" # ToDo: fix this
    })

  it "works in ref case", ->
    ex = facet("diamonds")
    expect(ex.toJS()).to.deep.equal({
      "op": "ref"
      "name": "diamonds"
    })

  it "works in uber-basic case", ->
    ex = facet()
      .def('five', 5)
      .def('nine', 9)

    console.log(ex.toJS())

  it "works in semi-realistic case", ->
    someDriver = {} # ToDo: fix this

    ex = facet()
      .def("diamonds",
        facet(someDriver)
          .filter("$color = 'D'")
          .def("priceOver2", "$price/2")
      )
      .def('Count', facet('diamonds').count())
      .def('TotalPrice', facet('diamonds').sum('$priceOver2'))

    console.log(ex.toJS())