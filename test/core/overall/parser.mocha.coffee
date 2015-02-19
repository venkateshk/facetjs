{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression } = facet.core

describe "parser", ->
  it "it should parse the mega definition", ->
    ex = facet()
      .apply('one', 1)
      .apply('two', 2)
      .apply('a', "$one + 10 - $two")
      .apply('b', "$one * 10 / $two")

    expect(ex.toJS()).to.deep.equal(
      facet()
      .apply('one', 1)
      .apply('two', 2)
      .apply('a', facet("one").add(10, facet("two").negate()))
      .apply('b', facet("one").multiply(10, facet("two").reciprocate()))
      .toJS()
    )