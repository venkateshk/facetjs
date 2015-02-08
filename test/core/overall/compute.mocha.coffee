{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.Core

describe "composition", ->
  data = [
    { cut: 'Good',  price: 400 }
    { cut: 'Good',  price: 300 }
    { cut: 'Great', price: 124 }
    { cut: 'Wow',   price: 160 }
    { cut: 'Wow',   price: 100 }
  ]

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

  it.skip "works with simple group aggregator", (done) ->
    ds = Dataset.fromJS({
      dataset: 'native'
      data: data
    })

    ex = facet()
    .apply('Data', facet(ds))
    .apply('Cuts'
      facet('Data').group('$cut')
    )

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        {
          "Data": {
            "data": data
            "dataset": "native"
            "type": "DATASET"
          }
          "Cuts": {
            "data": [
              { "Cut": "Good" }
              { "Cut": "Great" }
              { "Cut": "Wow" }
            ]
            "dataset": "native"
            "type": "DATASET"
          }
        }
      ])
      done()
    ).done()

  it "works with simple group aggregator + label", (done) ->
    ds = Dataset.fromJS({
      dataset: 'native'
      data: data
    })

    ex = facet()
      .apply('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
      )

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        {
          "Data": {
            "data": data
            "dataset": "native"
            "type": "DATASET"
          }
          "Cuts": {
            "data": [
              { "Cut": "Good" }
              { "Cut": "Great" }
              { "Cut": "Wow" }
            ]
            "dataset": "native"
            "type": "DATASET"
          }
        }
      ])
      done()
    ).done()

  it "works with simple group/label followed by some simple applies", (done) ->
    ds = Dataset.fromJS({
      dataset: 'native'
      data: data
    })

    ex = facet()
      .apply('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
          .apply('Six', 6)
          .apply('Seven', facet('Six').add(1))
      )

    #console.log("ex.toJS()", JSON.stringify(ex.toJS(), null, 2));

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        {
          "Data": {
            "data": data
            "dataset": "native"
            "type": "DATASET"
          }
          "Cuts": {
            "data": [
              {
                "Cut": "Good"
                "Six": 6
                "Seven": 7
              }
              {
                "Cut": "Great"
                "Six": 6
                "Seven": 7
              }
              {
                "Cut": "Wow"
                "Six": 6
                "Seven": 7
              }
            ]
            "dataset": "native"
            "type": "DATASET"
          }
        }
      ])
      done()
    ).done()

  it "works with simple group/label and subData filter", (done) ->
    ds = Dataset.fromJS({
      dataset: 'native'
      data: data
    })

    ex = facet()
      .apply('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
          .apply('Data', facet('^Data').filter(facet('cut').is('$^Cut')))
      )

    #console.log("ex.toJS()", JSON.stringify(ex.toJS(), null, 2));
    
    p = ex.compute()
    p.then((v) ->
      expect(v.toJS().data).to.deep.equal([
        {
          "Data": {
            "data": data
            "dataset": "native"
            "type": "DATASET"
          }
          "Cuts": {
            "data": [
              {
                "Cut": "Good"
                "Data": {
                  "data": [
                    {
                      "cut": "Good"
                      "price": 400
                    }
                    {
                      "cut": "Good"
                      "price": 300
                    }
                  ]
                  "dataset": "native"
                  "type": "DATASET"
                }
              }
              {
                "Cut": "Great"
                "Data": {
                  "data": [
                    {
                      "cut": "Great"
                      "price": 124
                    }
                  ]
                  "dataset": "native"
                  "type": "DATASET"
                }
              }
              {
                "Cut": "Wow"
                "Data": {
                  "data": [
                    {
                      "cut": "Wow"
                      "price": 160
                    }
                    {
                      "cut": "Wow"
                      "price": 100
                    }
                  ]
                  "dataset": "native"
                  "type": "DATASET"
                }
              }
            ]
            "dataset": "native"
            "type": "DATASET"
          }
        }
      ])
      done()
    ).done()