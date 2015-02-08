{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Shape } = facet.Core

describe "Shape", ->
  it "passes higher object tests", ->
    testHigherObjects(Shape, [
      {
        shape: 'rectangle'
        x: 0
        y: 0
        width: 800
        height: 600
      }
      {
        shape: 'rectangle'
        x: 0
        y: 0
        width: 300
        height: 200
      }
    ], {
      newThrows: true
    })

  describe "RectangularShape#margin", ->
    shape = Shape.rectangle(800, 600)

    it "works in basic case", ->
      newShape = shape.margin({
        top: 20
        right: 20
        bottom: 20
        left: 20
      })

      expect(newShape.x).to.equal(20)
      expect(newShape.y).to.equal(20)
      expect(newShape.width).to.equal(760)
      expect(newShape.height).to.equal(560)
