{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ Expression } = facet.core

describe "SQL parser", ->
  it "it should parse a total expression", ->
    ex = Expression.parseSQL("""
      SELECT
      SUM(added) AS 'TotalAdded'
      FROM `wiki`
      WHERE `language`="en"    -- This is just some comment
      GROUP BY ''
      """)

    ex2 = facet()
      .def('data', '$wiki.filter($language = "en")')
      .apply('TotalAdded', '$data.sum($added)')

    expect(ex.toJS()).to.deep.equal(ex2.toJS())

  it "it should parse a complex filter", ->
    ex = Expression.parseSQL("""
      SELECT
      SUM(added) AS 'TotalAdded'
      FROM `wiki`    -- Filters can have ANDs and all sorts of stuff!
      WHERE language="en" AND page="Hello World" AND added < 5
      GROUP BY ''
      """)

    ex2 = facet()
      .def('data',
        facet('wiki').filter(
          facet('language').is("en").and(facet('page').is("Hello World"), facet('added').lessThan(5))
        )
      )
      .apply('TotalAdded', '$data.sum($added)')

    expect(ex.toJS()).to.deep.equal(ex2.toJS())

  it "it should parse a total + split expression", ->
    ex = Expression.parseSQL("""
      SELECT
      SUM(`added`) AS 'TotalAdded',
      (
        SELECT
        `page` AS 'Page',
        COUNT() AS 'Count',
        SUM(`added`) AS 'TotalAdded',
        min(`added`) AS 'MinAdded',
        mAx(`added`) AS 'MaxAdded'
        GROUP BY `page`
        HAVING `TotalAdded` > 100
        ORDER BY `Count` DESC
        LIMIT 10
      ) AS 'Pages'
      FROM `wiki`
      WHERE `language`="en"
      GROUP BY ''
      """)

    ex2 = facet()
      .def('data', '$wiki.filter($language = "en")')
      .apply('TotalAdded', '$data.sum($added)')
      .apply('Pages',
        facet('data').split('$page', 'Page')
          .apply('Count', '$data.count()')
          .apply('TotalAdded', '$data.sum($added)')
          .apply('MinAdded', '$data.min($added)')
          .apply('MaxAdded', '$data.max($added)')
          .filter('$TotalAdded > 100')
          .sort('$Count', 'descending')
          .limit(10)
      )

    expect(ex.toJS()).to.deep.equal(ex2.toJS())
