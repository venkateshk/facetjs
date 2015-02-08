chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform, connector } = facet

{ simpleDriver } = require('../../build/driver/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet connector", ->
  afterEach ->
    d3.select('svg').remove()
    return

  describe "line", ->
    it.skip "properly draws a line", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .scale('count', scale.linear())
        .connector('topline', connector.line({
          color: 'blue',
          interpolate: 'monotone',
          width: 5,
          opacity: 0.5
        }))
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
            .transform(transform.rectangle.point({right:0}))
              .connect('topline')
            .render ->
              done()

  describe "area", ->
    it.skip "properly draws an area", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .scale('count', scale.linear())
        .connector('area', connector.area({
          color: 'orange',
          interpolate: 'monotone',
          opacity: 0.3
        }))
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
            .transform(transform.rectangle.line({direction: 'horizontal'}))
              .connect('area')
            .render ->
              done()
