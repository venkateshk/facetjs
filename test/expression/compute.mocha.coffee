{ expect } = require("chai")

{ Dataset } = require('../../build/datatype')
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

  it "works in existing dataset case", (done) ->
    ds = Dataset.fromJS({
      dataset: 'native'
      data: [
        { cut: 'Good',  price: 400 }
        { cut: 'Great', price: 124 }
        { cut: 'Wow',   price: 160 }
      ]
    })

    ex = facet(ds)
      .apply('priceX2', facet('price').multiply(2))

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        { cut: 'Good',  price: 400, priceX2: 800 }
        { cut: 'Great', price: 124, priceX2: 248 }
        { cut: 'Wow',   price: 160, priceX2: 320 }
      ])
      done()
    ).done()