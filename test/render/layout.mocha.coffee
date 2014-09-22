chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform } = facet

{ simpleDriver } = require('../../build/driver/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet layout", ->
  afterEach ->
    d3.select('svg').remove()
    return

  describe "vertical layout", ->
    it "should make groups with the right sizes", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.vertical())
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            'translate(0,0)',
            'translate(0,120)',
            'translate(0,240)',
            'translate(0,360)',
            'translate(0,480)'
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

    it "should make the right sizes of groups given the size argument", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.vertical({size: use.prop('Count')}))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            "translate(0,0)"
            "translate(0,239.72191323692994)"
            "translate(0,393.12569521690773)"
            "translate(0,527.519466073415)"
            "translate(0,582.091212458287)"
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

    it "should make the right gap", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.vertical({ gap: 10 }))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            'translate(0,0)',
            'translate(0,122)',
            'translate(0,244)',
            'translate(0,366)',
            'translate(0,488)'
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

  describe "horizontal layout", ->
    it "should make groups with the right sizes", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.horizontal())
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            'translate(0,0)',
            'translate(160,0)',
            'translate(320,0)',
            'translate(480,0)',
            'translate(640,0)'
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

    it "should make the right sizes of groups given the size argument", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.horizontal({size: use.prop('Count')}))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            "translate(0,0)"
            "translate(319.62921764923993,0)"
            "translate(524.1675936225436,0)"
            "translate(703.3592880978865,0)"
            "translate(776.1216166110493,0)"
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

    it "should make the right gap", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .split('Cut', split.identity('cut'))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .layout(layout.horizontal({ gap: 10 }))
        .render ->
          groups = d3.select('svg').selectAll('g')
          expectedTransforms = [
            'translate(0,0)',
            'translate(162,0)',
            'translate(324,0)',
            'translate(486,0)',
            'translate(648,0)'
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()

  describe "horizontalScale layout", ->
    it "should throw error when no args is supplied", (done) ->
      expect( ->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .split('Cut', split.identity('cut'))
          .apply('Count', apply.count())
          .combine(combine.slice(sort.natural('Count'), 5))
          .layout(layout.horizontalScale())
      ).to.throw(Error, /Must have args/)
      done()

    it "should throw error when no scale is supplied", (done) ->
      expect( ->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .split('Cut', split.identity('cut'))
          .apply('Count', apply.count())
          .combine(combine.slice(sort.natural('Count'), 5))
          .layout(layout.horizontalScale({}))
      ).to.throw(Error, /Must have a scale/)
      done()

    it "should make groups with the right sizes", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .scale('horiz', scale.linear())
        .range('horiz', use.space('width'))
        .split('Carat', split.continuous('carat', 0.1))
        .apply('Count', apply.count())
        .combine(combine.slice(sort.natural('Count'), 5))
        .domain('horiz', use.prop('Carat'))
        .layout(layout.horizontalScale({scale: 'horiz'}))
        .render ->
          groups = d3.select('svg').selectAll('g')

          expectedTransforms = [
            "translate(88.8888888888889,0)",
            "translate(711.1111111111111,0)",
            "translate(266.66666666666663,0)",
            "translate(177.77777777777777,0)",
            "translate(0,0)"
          ]
          expect(groups.size()).to.equal(5)
          groups.each((d, i) ->
            expect(d3.select(this).attr('transform')).equal(expectedTransforms[i])
          )
          done()
