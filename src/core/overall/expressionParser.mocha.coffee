{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ Expression } = facet

describe "expression parser", ->
  it "it should parse the mega definition", ->
    ex = facet()
      .filter('$color = "Red"')
      .filter('$price < 5')
      .filter('$country.is("USA")')
      .apply('parent_x', "$^x")
      .apply('typed_y', "$y:STRING")
      .apply('sub_typed_z', "$z:SET/STRING")
      .apply('addition1', "$x + 10 - $y")
      .apply('addition2', "$x.add(1)")
      .apply('multiplication1', "$x * 10 / $y")
      .apply('multiplication2', "$x.multiply($y)")
      .apply('agg_count', "$data.count()")
      .apply('agg_sum', "$data.sum($price)")
      .apply('agg_group', "$data.group($carat)")
      .apply('agg_group_label1', "$data.group($carat).label('Carat')")
      .apply('agg_group_label2', "$data.group($carat).label('Carat')")
      .apply('agg_filter_count', "$data.filter($country = 'USA').count()")

    ex2 = facet()
      .filter(facet('color').is("Red"))
      .filter(facet('price').lessThan(5))
      .filter(facet('country').is("USA"))
      .apply('parent_x', facet("^x"))
      .apply('typed_y', { op: 'ref', name: 'y', type: 'STRING' })
      .apply('sub_typed_z', { op: 'ref', name: 'z', type: 'SET/STRING' })
      .apply('addition1', facet("x").add(10, facet("y").negate()))
      .apply('addition2', facet("x").add(1))
      .apply('multiplication1', facet("x").multiply(10, facet("y").reciprocate()))
      .apply('multiplication2', facet("x").multiply(facet('y')))
      .apply('agg_count', facet("data").count())
      .apply('agg_sum', facet("data").sum(facet('price')))
      .apply('agg_group', facet("data").group(facet('carat')))
      .apply('agg_group_label1', facet("data").group(facet('carat')).label('Carat'))
      .apply('agg_group_label2', facet("data").group('$carat').label('Carat'))
      .apply('agg_filter_count', facet("data").filter(facet('country').is("USA")).count())

    expect(ex.toJS()).to.deep.equal(ex2.toJS())

  it "it should parse a whole expression", ->
    ex = Expression.parse("""
      facet()
        .def(num, 5)
        .apply(subData,
          facet()
            .apply(x, $num + 1)
            .apply(y, $foo * 2)
        )
      """)

    ex2 = facet()
      .def('num', 5)
      .apply('subData',
        facet()
          .apply('x', '$num + 1')
          .apply('y', '$foo * 2')
      )

    expect(ex.toJS()).to.deep.equal(ex2.toJS())

  it "it should parse a whole complex expression", ->
    ex = Expression.parse("""
      facet()
        .def(wiki, $wiki.filter($language = 'en'))
        .apply(Count, $wiki.sum($count))
        .apply(TotalAdded, $wiki.sum($added))
        .apply(Pages,
          $wiki.split($page, Page)
            .apply(Count, $wiki.sum($count))
            .sort($Count, descending)
            .limit(2)
            .apply(Time,
              $wiki.split($time.timeBucket(PT1H, 'Etc/UTC'), Timestamp)
                .apply(TotalAdded, $wiki.sum($added))
                .sort($TotalAdded, descending)
                .limit(3)
            )
        )
      """)

    ex2 = facet()
      .def("wiki", facet('wiki').filter(facet("language").is('en')))
      .apply('Count', '$wiki.sum($count)')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Pages',
        facet("wiki").split("$page", 'Page')
          .apply('Count', '$wiki.sum($count)')
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            facet("wiki").split(facet("time").timeBucket('PT1H', 'Etc/UTC'), 'Timestamp')
              .apply('TotalAdded', '$wiki.sum($added)')
              .sort('$TotalAdded', 'descending')
              .limit(3)
          )
      )

    expect(ex.toJS()).to.deep.equal(ex2.toJS())