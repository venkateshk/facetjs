{ expect } = require("chai")

{ Shape, RectangularShape } = require('../../build/datatype/shape')

describe "Shape", ->
  describe "RectangularShape#margin", ->
    shape = RectangularShape.base(800, 600)

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
