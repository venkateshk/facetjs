chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform } = facet

simpleDriver = require('../../build/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet split", ->
  afterEach ->
    d3.select('svg').remove()
    return

  describe "one split", ->
    it "should make the right number of groups", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count')))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expect(groups.size()).to.equal(5)
          done()

    it "should make the right number of groups with combine limits", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 3))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expect(groups.size()).to.equal(3)
          done()

  describe "with two splits", ->
    it "should make the right number of groups", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
          .split('Clarity', split.identity('clarity'))
          .apply('Count', apply.count())
          .combine(combine.slice(sort.natural('Count'), 5))
          .render ->
            groups = d3.select('svg').selectAll('g').selectAll('g')
            expect(groups.size()).to.equal(25)
            done()