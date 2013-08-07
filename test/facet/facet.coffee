chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform } = facet

simpleDriver = require('../../build/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet", ->
  it "should make the right number of groups", (done) ->
    facet.define('body', 800, 600, diamondsSimpleDriver)
      .scale('color', scale.color())
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .apply('AvgPrice', apply.average('price'))
        .combine(combine.slice(sort.natural('AvgPrice', 'descending')))
        .layout(layout.vertical({ size: use.prop('Count'), gap: 3 }))
        .domain('color', use.prop('Cut'))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expect(groups[0].length).to.equal(5)
          done()
