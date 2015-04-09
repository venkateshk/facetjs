{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ legacyConverter, legacyTranslator, Dataset } = facet
{ nativeDriver } = facet.legacy

diamondsData = require('../../data/diamonds.js')

legacyDriver = legacyConverter(nativeDriver(diamondsData))

describe "legacyDriver", ->
  describe.skip "simple query", ->
    ex = facet()
      .apply('Count', facet('diamonds').count())
      .apply('TotalPrice', facet('diamonds').sum('$price'))

    it "works", (testComplete) ->
      legacyDriver(ex)
      .then((data) ->
        expect(data.toJS()).to.deep.equal([
          {
            "Count": 6775
            "TotalPrice": 21476439
          }
        ])
        testComplete()
      )
      .done()


  describe "advanced query", ->
    ex = facet()
      .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
      .apply('Count', facet('diamonds').count())
      .apply('TotalPrice', facet('diamonds').sum('$price'))
      .apply('Cuts',
        facet("diamonds").group("$cut").label('Cut')
          .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
          .apply('Count', facet('diamonds').count())
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Carats',
            facet("diamonds").split(facet("carat").numberBucket(0.25), 'Carat')
              .apply('Count', facet('diamonds').count())
              .sort('$Count', 'descending')
              .limit(3)
          )
      )

    it "translates", ->
      expect(legacyTranslator(ex).toJS()).to.deep.equal([
        {
          "attribute": "color"
          "operation": "filter"
          "type": "is"
          "value": "D"
        }
        {
          "aggregate": "count"
          "name": "Count"
          "operation": "apply"
        }
        {
          "aggregate": "sum"
          "attribute": "price"
          "name": "TotalPrice"
          "operation": "apply"
        }
        {
          "attribute": "cut"
          "bucket": "identity"
          "name": "Cut"
          "operation": "split"
        }
        {
          "aggregate": "count"
          "name": "Count"
          "operation": "apply"
        }
        {
          "limit": 2
          "method": "slice"
          "operation": "combine"
          "sort": {
            "compare": "natural"
            "direction": "descending"
            "prop": "Count"
          }
        }
        {
          "attribute": "carat"
          "bucket": "continuous"
          "name": "Carat"
          "offset": 0
          "operation": "split"
          "size": 0.25
        }
        {
          "aggregate": "count"
          "name": "Count"
          "operation": "apply"
        }
        {
          "limit": 3
          "method": "slice"
          "operation": "combine"
          "sort": {
            "compare": "natural"
            "direction": "descending"
            "prop": "Count"
          }
        }
      ])

    it "works", (testComplete) ->
      legacyDriver(ex)
      .then((data) ->
        expect(data.toJS()).to.deep.equal([
          {
            "Count": 6775
            "Cut": [
              {
                "Carat": [
                  {
                    "Carat": {
                      "end": 0.5
                      "start": 0.25
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 1360
                  }
                  {
                    "Carat": {
                      "end": 0.75
                      "start": 0.5
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 919
                  }
                  {
                    "Carat": {
                      "end": 1.25
                      "start": 1
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 298
                  }
                ]
                "Count": 2834
                "Cut": "Ideal"
              }
              {
                "Carat": [
                  {
                    "Carat": {
                      "end": 0.5
                      "start": 0.25
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 568
                  }
                  {
                    "Carat": {
                      "end": 0.75
                      "start": 0.5
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 396
                  }
                  {
                    "Carat": {
                      "end": 1.25
                      "start": 1
                      "type": "NUMBER_RANGE"
                    }
                    "Count": 328
                  }
                ]
                "Count": 1603
                "Cut": "Premium"
              }
            ]
            "TotalPrice": 21476439
          }
        ])
        testComplete()
      )
      .done()
