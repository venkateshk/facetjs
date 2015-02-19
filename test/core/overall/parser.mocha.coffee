{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression } = facet.core

describe "parser", ->
  it "it should parse the mega definition", ->
    ex = facet()
      .apply('addition', "$x + 10 - $y")
      .apply('multiplication', "$x * 10 / $y")
      .apply('agg_count', "$data.count()")
      .apply('agg_sum', "$data.sum($price)")

    expect(ex.toJS()).to.deep.equal(
      facet()
      .apply('addition', facet("x").add(10, facet("y").negate()))
      .apply('multiplication', facet("x").multiply(10, facet("y").reciprocate()))
      .apply('agg_count', facet("data").count())
      .apply('agg_sum', facet("data").sum(facet('price')))
      .toJS()
    )