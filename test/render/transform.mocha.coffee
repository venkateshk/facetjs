chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform } = facet

{ simpleDriver } = require('../../build/driver/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet transform", ->
  afterEach ->
    d3.select('svg').remove()
    return

  describe "rectangle", ->
    describe "point", ->

    describe "line", ->

    describe "rectangle", ->
      it "should create another group element inside parent group", (done) ->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .transform(transform.rectangle.rectangle())
          .plot(plot.box({
            fill: '#f0f0f0',
            stroke: 'black'
          }))
          .render ->
            expect(d3.select('svg').selectAll('g').size()).to.equal(1)
            done()
        return

      it "should work well with constant values", (done) ->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .transform(transform.rectangle.rectangle({left: 10, right: 10, top: 10, bottom: 10}))
          .plot(plot.box({
            fill: '#f0f0f0',
            stroke: 'black'
          }))
          .render ->
            expect(d3.select('svg').selectAll('g').size()).to.equal(1)
            expect(d3.select('svg').html()).to.equal('<g transform="translate(10,10)"><rect style="fill: #f0f0f0; stroke: black;" x="0" y="0" width="780" height="580"></rect></g>')
            done()
        return

      it.skip "should work well with scale", (done) ->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .scale('count', scale.linear())
          .split('Clarity', split.identity('clarity'))
            .apply('Count', apply.count())
            .combine(combine.slice(sort.natural('Count'), 5))
            .layout(layout.vertical())
            .range('count', use.space('width'))
            .domain('count', use.interval(0, use.prop('Count')))
            .transform(transform.rectangle.rectangle({
              left: 0,
              width: use.scale('count')
            }))
            .plot(plot.box({
              fill: '#f0f0f0',
              stroke: 'black'
            }))
            .render ->
              done()
