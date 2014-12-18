{ expect } = require("chai")

{ Space, RectangularSpace } = require('../../build/render/space')

describe "Space", ->
  describe "RectangularSpace#margin", ->
    space = RectangularSpace.base(800, 600)

    it "works in basic case", ->
      newSpace = space.margin({
        top: 20
        right: 20
        bottom: 20
        left: 20
      })

      expect(newSpace.x({})).to.equal(20)
      expect(newSpace.y({})).to.equal(20)
      expect(newSpace.width({})).to.equal(760)
      expect(newSpace.height({})).to.equal(560)

    it "works in function case", ->
      newSpace = space.margin({
        top: (d) -> d.foo
        right: (d) -> d.foo
        bottom: (d) -> d.foo
        left: (d) -> d.foo
      })

      expect(newSpace.x({ foo: 20 })).to.equal(20)
      expect(newSpace.y({ foo: 20 })).to.equal(20)
      expect(newSpace.width({ foo: 20 })).to.equal(760)
      expect(newSpace.height({ foo: 20 })).to.equal(560)

      expect(newSpace.x({ foo: 50 })).to.equal(50)
      expect(newSpace.y({ foo: 50 })).to.equal(50)
      expect(newSpace.width({ foo: 50 })).to.equal(700)
      expect(newSpace.height({ foo: 50 })).to.equal(500)
