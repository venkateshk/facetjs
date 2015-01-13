{ expect } = require("chai")

{ Shape, RectangularShape } = require('../../build/render/shape')

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

    it "works in function case", ->
      newShape = shape.margin({
        top: (d) -> d.foo
        right: (d) -> d.foo
        bottom: (d) -> d.foo
        left: (d) -> d.foo
      })

      expect(newShape.x({ foo: 20 })).to.equal(20)
      expect(newShape.y({ foo: 20 })).to.equal(20)
      expect(newShape.width({ foo: 20 })).to.equal(760)
      expect(newShape.height({ foo: 20 })).to.equal(560)

      expect(newShape.x({ foo: 50 })).to.equal(50)
      expect(newShape.y({ foo: 50 })).to.equal(50)
      expect(newShape.width({ foo: 50 })).to.equal(700)
      expect(newShape.height({ foo: 50 })).to.equal(500)
