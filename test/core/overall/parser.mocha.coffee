{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression } = facet.core

describe "parser", ->
  it "it should parse the mega definition", ->
    ex = facet()
      #.filter('$color = "Red"')
      #.filter('$country.is("USA")')
      .apply('parent_x', "$^x")
      .apply('typed_y', "$y:STRING")
      .apply('sub_typed_z', "$z:SET/STRING")
      .apply('addition1', "$x + 10 - $y")
      #.apply('addition2', "$x.add(1)")
      .apply('multiplication', "$x * 10 / $y")
      .apply('agg_count', "$data.count()")
      .apply('agg_sum', "$data.sum($price)")
      .apply('agg_group', "$data.group($carat)")
      .apply('agg_group_label1', "$data.group($carat).label('Carat')")
      .apply('agg_group_label2', "$data.group($carat).label('Carat')")

    expect(ex.toJS()).to.deep.equal(
      facet()
      #.filter(facet('color').is("Red")')
      #.filter(facet('country').is("USA")')
      .apply('parent_x', facet("^x"))
      .apply('typed_y', { op: 'ref', name: 'y', type: 'STRING' })
      .apply('sub_typed_z', { op: 'ref', name: 'z', type: 'SET/STRING' })
      .apply('addition1', facet("x").add(10, facet("y").negate()))
      #.apply('addition2', facet("x").add(1))
      .apply('multiplication', facet("x").multiply(10, facet("y").reciprocate()))
      .apply('agg_count', facet("data").count())
      .apply('agg_sum', facet("data").sum(facet('price')))
      .apply('agg_group', facet("data").group(facet('carat')))
      .apply('agg_group_label1', facet("data").group(facet('carat')).label('Carat'))
      .apply('agg_group_label2', facet("data").group('$carat').label('Carat'))
      .toJS()
    )
