chai = require("chai")
expect = chai.expect

d3 = require("d3")

facet = require('../../build/facet')
{ filter, split, apply, layout, scale, plot, use, combine, sort, transform } = facet

simpleDriver = require('../../build/simpleDriver')
diamondsData = require('../../data/diamonds.js')
diamondsSimpleDriver = simpleDriver(diamondsData)

describe "Facet layout", ->
  afterEach ->
    d3.select('svg').remove()
    return

  describe "box", ->
    it "should create a box with correct properties when fill and stroke are supplied", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .plot(plot.box({
          fill: '#f0f0f0',
          stroke: 'black'
        }))
        .render ->
          box = d3.select('svg').selectAll('rect')
          expect(box.attr('x')).to.equal('0')
          expect(box.attr('y')).to.equal('0')
          expect(box.attr('width')).to.equal('800')
          expect(box.attr('height')).to.equal('600')
          expect(box.style('fill')).to.equal('#f0f0f0')
          expect(box.style('stroke')).to.equal('black')
          done()

    it "should create a box with correct properties when color and stroke are supplied", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .plot(plot.box({
          color: '#f0f0f0',
          stroke: 'black'
        }))
        .render ->
          box = d3.select('svg').selectAll('rect')
          expect(box.attr('x')).to.equal('0')
          expect(box.attr('y')).to.equal('0')
          expect(box.attr('width')).to.equal('800')
          expect(box.attr('height')).to.equal('600')
          expect(box.style('fill')).to.equal('#f0f0f0')
          expect(box.style('stroke')).to.equal('black')
          done()

    it "should create a box without arguments", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .plot(plot.box())
        .render ->
          box = d3.select('svg').selectAll('rect')
          expect(box.attr('x')).to.equal('0')
          expect(box.attr('y')).to.equal('0')
          expect(box.attr('width')).to.equal('800')
          expect(box.attr('height')).to.equal('600')
          expect(box.style('fill')).to.equal('')
          expect(box.style('stroke')).to.equal('')
          done()

    it "should throw Error with a wrong stage type", (done) ->
      expect(->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .transform(transform.rectangle.point({ bottom: 6 }))
          .plot(plot.box())
          .render()
      ).to.throw(Error, /Box must have a rectangle stage/)
      done()

  describe "label", ->
    it "should create a label with correct properties", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.point({ bottom: 6 }))
        .plot(plot.label({
          color: '#f0f0f0'
          text: 'Hello World'
          size: 15
          baseline: 'top'
          anchor: 'middle'
          angle: 90
        }))
        .render ->
          label = d3.select('svg').selectAll('text')
          expect(label.style('fill')).to.equal('#f0f0f0')
          expect(label.text()).to.equal('Hello World')
          expect(label.style('font-size')).to.equal("15")
          expect(label.style('text-anchor')).to.equal('middle')
          expect(label.attr('dy')).to.equal('.71em')
          expect(label.attr('transform')).to.equal('rotate(-90)')
          done()

    it "should create a label without arguments", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.point({ bottom: 6 }))
        .plot(plot.label())
        .render ->
          label = d3.select('svg').selectAll('text')
          expect(label.text()).to.equal('Label')
          done()

    it "should throw Error with a wrong stage type", (done) ->
      expect(->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .plot(plot.label())
          .render()
      ).to.throw(Error, /Label must have a point stage/)
      done()

  describe "circle", ->
    it "should create a circle with correct properties with radius, stroke and fill", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.point({ bottom: 6 }))
        .plot(plot.circle({
          radius: 10
          stroke: 'black'
          fill: '#f0f0f0'
        }))
        .render ->
          circle = d3.select('svg').selectAll('circle')
          expect(circle.style('fill')).to.equal('#f0f0f0')
          expect(circle.attr('r')).to.equal("10")
          expect(circle.style('stroke')).to.equal('black')
          done()

    it "should create a circle with correct properties with area, stroke and color", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.point({ bottom: 6 }))
        .plot(plot.circle({
          area: 9 * Math.PI
          stroke: 'black'
          color: '#f0f0f0'
        }))
        .render ->
          circle = d3.select('svg').selectAll('circle')
          expect(circle.style('fill')).to.equal('#f0f0f0')
          expect(circle.attr('r')).to.equal("3")
          expect(circle.style('stroke')).to.equal('black')
          done()

    it "should create a circle without arguments", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.point({ bottom: 6 }))
        .plot(plot.circle())
        .render ->
          circle = d3.select('svg').selectAll('circle')
          expect(circle.attr('r')).to.equal('5')
          done()

    it "should throw Error when overconstrained by area and radius", (done) ->
      expect(->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .plot(plot.circle({
            radius: 10
            area: 15
          }))
          .render()
      ).to.throw(Error, /Over-constrained by radius and area/)
      done()

    it "should throw Error with a wrong stage type", (done) ->
      expect(->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .plot(plot.circle())
          .render()
      ).to.throw(Error, /Circle must have a point stage/)
      done()

  describe "line", ->
    it "should create a line with correct properties", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.line({ direction: 'vertical' }))
        .plot(plot.line({
          stroke: 'black'
        }))
        .render ->
          line = d3.select('svg').selectAll('line')
          expect(line.attr('x1')).to.equal('-300')
          expect(line.attr('x2')).to.equal('300')
          expect(line.style('stroke')).to.equal('black')
          done()

    it "should create a line without arguments", (done) ->
      facet.define('body', 800, 600, diamondsSimpleDriver)
        .transform(transform.rectangle.line({ direction: 'vertical' }))
        .plot(plot.line())
        .render ->
          line = d3.select('svg').selectAll('line')
          expect(line.attr('x1')).to.equal('-300')
          expect(line.attr('x2')).to.equal('300')
          done()

    it "should throw Error with a wrong stage type", (done) ->
      expect(->
        facet.define('body', 800, 600, diamondsSimpleDriver)
          .plot(plot.line())
          .render()
      ).to.throw(Error, /Line must have a line stage/)
      done()
