{ expect } = require("chai")

facet = require('../../build/facet')
{ Expression, $ } = facet

describe "substitute", ->
  it "should substitute on IS", ->
    ex = $(5).is('$hello')

    subs = (ex) ->
      if ex.op is 'literal' and ex.type is 'NUMBER'
        return Expression.fromJSLoose(ex.value + 10)
      else
        return null

    expect(ex.substitute(subs).toJS()).to.deep.equal(
      $(15).is('$hello').toJS()
    )

  it "should substitute on complex expression", ->
    ex = $()
      .def('num', 5)
      .apply('subData',
        $()
          .apply('x', '$num + 1')
          .apply('y', '$foo * 2')
          .apply('z', $().sum('$a + 3'))
          .apply('w', $().sum('$a + 4 + $b'))
      )

    subs = (ex) ->
      if ex.op is 'literal' and ex.type is 'NUMBER'
        return Expression.fromJSLoose(ex.value + 10)
      else
        return null

    expect(ex.substitute(subs).toJS()).to.deep.equal(
      $()
        .def('num', 15)
        .apply('subData',
          $()
            .apply('x', '$num + 11')
            .apply('y', '$foo * 12')
            .apply('z', $().sum('$a + 13'))
            .apply('w', $().sum('$a + 14 + $b'))
        )
        .toJS()
    )
