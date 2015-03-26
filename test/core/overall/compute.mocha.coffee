{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.core

describe "compute native", ->
  data = [
    { cut: 'Good',  price: 400 }
    { cut: 'Good',  price: 300 }
    { cut: 'Great', price: 124 }
    { cut: 'Wow',   price: 160 }
    { cut: 'Wow',   price: 100 }
  ]

  it "works in uber-basic case", (testComplete) ->
    ex = facet()
      .apply('five', 5)
      .apply('nine', 9)

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          five: 5
          nine: 9
        }
      ])
      testComplete()
    ).done()

  it "works in existing dataset case", (testComplete) ->
    ds = Dataset.fromJS([
      { cut: 'Good',  price: 400 }
      { cut: 'Great', price: 124 }
      { cut: 'Wow',   price: 160 }
    ])

    ex = facet(ds)
      .apply('priceX2', facet('price').multiply(2))

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        { cut: 'Good',  price: 400, priceX2: 800 }
        { cut: 'Great', price: 124, priceX2: 248 }
        { cut: 'Wow',   price: 160, priceX2: 320 }
      ])
      testComplete()
    ).done()

  it "works with simple group aggregator", (testComplete) ->
    ds = Dataset.fromJS(data)

    ex = facet()
    .def('Data', facet(ds))
    .apply('Cuts'
      facet('Data').group('$cut')
    )

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          "Cuts": {
            "type": "SET"
            "setType": "STRING"
            "elements": ["Good", "Great", "Wow"]
          }
        }
      ])
      testComplete()
    ).done()

  it "works with simple group aggregator + label", (testComplete) ->
    ds = Dataset.fromJS(data)

    ex = facet()
      .def('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
      )

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          "Cuts": [
            { "Cut": "Good" }
            { "Cut": "Great" }
            { "Cut": "Wow" }
          ]
        }
      ])
      testComplete()
    ).done()

  it "works with simple group/label followed by some simple applies", (testComplete) ->
    ds = Dataset.fromJS(data)

    ex = facet()
      .def('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
          .apply('Six', 6)
          .apply('Seven', facet('Six').add(1))
      )

    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          "Cuts": [
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
        }
      ])
      testComplete()
    ).done()

  it "works with context", (testComplete) ->
    ds = Dataset.fromJS(data)

    ex = facet()
      .def('Data', facet(ds))
      .apply('Cuts'
        facet('Data').split('$cut', 'Cut')
          .apply('CountPlusX', '$Data.count() + $x')
      )

    p = ex.compute({ x: 13 })
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          "Cuts": [
            {
              "CountPlusX": 15
              "Cut": "Good"
            }
            {
              "CountPlusX": 14
              "Cut": "Great"
            }
            {
              "CountPlusX": 15
              "Cut": "Wow"
            }
          ]
        }
      ])
      testComplete()
    ).done()

  it "works with simple group/label and subData filter", (testComplete) ->
    ds = Dataset.fromJS(data)

    ex = facet()
      .def('Data', facet(ds))
      .apply('Cuts'
        facet('Data').group('$cut').label('Cut')
          .apply('Data', facet('^Data').filter(facet('cut').is('$^Cut')))
      )
    
    p = ex.compute()
    p.then((v) ->
      expect(v.toJS()).to.deep.equal([
        {
          "Cuts": [
            {
              "Cut": "Good"
              "Data": [
                {
                  "cut": "Good"
                  "price": 400
                }
                {
                  "cut": "Good"
                  "price": 300
                }
              ]
            }
            {
              "Cut": "Great"
              "Data": [
                {
                  "cut": "Great"
                  "price": 124
                }
              ]
            }
            {
              "Cut": "Wow"
              "Data": [
                {
                  "cut": "Wow"
                  "price": 160
                }
                {
                  "cut": "Wow"
                  "price": 100
                }
              ]
            }
          ]
        }
      ])
      testComplete()
    ).done()

  describe "unions", ->
    it "does a union", (testComplete) ->
      ds = Dataset.fromJS(data)

      ex = facet()
        .def('Data1', facet(ds).filter(facet('price').in(105, 305)))
        .def('Data2', facet(ds).filter(facet('price').in(105, 305).not()))
        .apply('Count1', '$Data1.count()')
        .apply('Count2', '$Data2.count()')
        .apply('Cuts'
          facet('Data1').group('$cut').union(facet('Data2').group('$cut')).label('Cut')
            .def('Data1', facet('^Data1').filter(facet('cut').is('$^Cut')))
            .def('Data2', facet('^Data2').filter(facet('cut').is('$^Cut')))
            .apply('Counts', '10 * $Data1.count() + $Data2.count()')
        )
      
      p = ex.compute()
      p.then((v) ->
        midData = v
        expect(midData.toJS()).to.deep.equal([
          {
            "Count1": 3
            "Count2": 2
            "Cuts": [
              {
                "Counts": 11
                "Cut": "Good"
              }
              {
                "Counts": 10
                "Cut": "Great"
              }
              {
                "Counts": 11
                "Cut": "Wow"
              }
            ]
          }
        ])
        testComplete()
      ).done()


  #      data = [
  #        { cut: 'Good',  price: 400 }
  #        { cut: 'Good',  price: 300 }
  #        { cut: 'Great', price: 124 }
  #        { cut: 'Wow',   price: 160 }
  #        { cut: 'Wow',   price: 100 }
  #      ]

  describe "it works and re-selects", ->
    ds = Dataset.fromJS(data)
    midData = null

    it "works with simple group/label and subData filter with applies", (testComplete) ->
      ex = facet()
        .def('Data', facet(ds))
        .apply('Count', '$Data.count()')
        .apply('Price', '$Data.sum($price)')
        .apply('Cuts'
          facet('Data').group('$cut').label('Cut')
            .def('Data', facet('^Data').filter(facet('cut').is('$^Cut')))
            .apply('Count', '$Data.count()')
            .apply('Price', '$Data.sum($price)')
        )

      p = ex.compute()
      p.then((v) ->
        midData = v
        expect(midData.toJS()).to.deep.equal([
          {
            "Count": 5
            "Price": 1084
            "Cuts": [
              {
                "Cut": "Good"
                "Count": 2
                "Price": 700
              }
              {
                "Cut": "Great"
                "Count": 1
                "Price": 124
              }
              {
                "Cut": "Wow"
                "Count": 2
                "Price": 260
              }
            ]
          }
        ])
        testComplete()
      ).done()

    it "re-selects", (testComplete) ->
      ex = facet(midData)
        .apply('CountOver2', '$Count / 2')
        .apply('Cuts'
          facet('Cuts')
            .apply('AvgPrice', '$Data.sum($price) / $Data.count()')
        )

      p = ex.compute()
      p.then((v) ->
        expect(v.toJS()).to.deep.equal([
          {
            "Count": 5
            "CountOver2": 2.5
            "Cuts": [
              {
                "AvgPrice": 350
                "Count": 2
                "Cut": "Good"
                "Price": 700
              }
              {
                "AvgPrice": 124
                "Count": 1
                "Cut": "Great"
                "Price": 124
              }
              {
                "AvgPrice": 130
                "Count": 2
                "Cut": "Wow"
                "Price": 260
              }
            ]
            "Price": 1084
          }
        ])
        testComplete()
      ).done()
