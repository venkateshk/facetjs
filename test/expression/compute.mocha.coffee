{ expect } = require("chai")

{ Expression } = require('../../build/expression')

describe "composition", ->
  facet = Expression.facet

  it "works in uber-basic case", (done) ->
    ex = facet()
      .apply('five', 5)
      .apply('nine', 9)

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        {
          five: 5
          nine: 9
        }
      ])
      done()
    ).done()
