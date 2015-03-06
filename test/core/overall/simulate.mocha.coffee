{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.core

describe "simulate", ->
  it "works in advanced case", ->
    context = {
      diamonds: Dataset.fromJS({
        source: 'druid',
        dataSource: 'diamonds',
        timeAttribute: 'time',
        forceInterval: true,
        approximate: true,
        context: null
        attributes: {
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'STRING' }
          price: { type: 'NUMBER' }
        }
      })
    }

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
            facet("diamonds").group(facet("carat").numberBucket(0.25)).label('Carat')
              .def('diamonds', facet('diamonds').filter(facet("carat").numberBucket(0.25).is('$^Carat')))
              .apply('Count', facet('diamonds').count())
              .sort('$Count', 'descending')
              .limit(3)
          )
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
          {
            "fieldName": "price"
            "name": "TotalPrice"
            "type": "doubleSum"
          }
        ]
        "dataSource": "diamonds"
        "filter": {
          "dimension": "color"
          "type": "selector"
          "value": "D"
        }
        "granularity": "all"
        "intervals": [
          "1000-01-01/3000-01-01"
        ]
        "queryType": "timeseries"
      }
      # -------------
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "cut"
          "outputName": "Cut"
          "type": "default"
        }
        "filter": {
          "dimension": "color"
          "type": "selector"
          "value": "D"
        }
        "granularity": "all"
        "intervals": [
          "1000-01-01/3000-01-01"
        ]
        "queryType": "topN"
      }
      # -------------
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimExtractionFn": {
            "function": "function(d){d=Number(d); if(isNaN(d)) return 'null'; return Math.floor(d / 0.25) * 0.25;}"
            "type": "javascript"
          }
          "dimension": "carat"
          "outputName": "Carat"
          "type": "extraction"
        }
        "filter": {
          "fields": [
            {
              "dimension": "color"
              "type": "selector"
              "value": "D"
            }
            {
              "dimension": "cut"
              "type": "selector"
              "value": "some_cut"
            }
          ]
          "type": "and"
        }
        "granularity": "all"
        "intervals": [
          "1000-01-01/3000-01-01"
        ]
        "queryType": "topN"
      }
    ])
