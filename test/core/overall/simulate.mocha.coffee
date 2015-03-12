{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ Expression, Dataset, TimeRange } = facet.core

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
          time: { type: 'TIME' }
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'STRING' }
          price: { type: 'NUMBER' }
          tax: { type: 'NUMBER' }
        }
        filter: facet("time").in(TimeRange.fromJS({
          start: new Date('2015-03-12T00:00:00')
          end:   new Date('2015-03-19T00:00:00')
        }))
      })
    }

    ex = facet()
      .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
      .apply('Count', '$diamonds.count()')
      .apply('TotalPrice', '$diamonds.sum($price)')
      .apply('PriceTimes2', '$diamonds.sum($price) * 2')
      .apply('PriceAndTax', '$diamonds.sum($price) * $diamonds.sum($tax)')
      .apply('PriceGoodCut', facet('diamonds').filter(facet('cut').is('good')).sum('$price'))
      .apply('Cuts',
        facet("diamonds").split("$cut", 'Cut')
          .apply('Count', facet('diamonds').count())
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            facet("diamonds").split(facet("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
              .apply('TotalPrice', facet('diamonds').sum('$price'))
              #.sort('$Timestamp', 'ascending')
              #.limit(10)
              .apply('Carats',
                facet("diamonds").split(facet("carat").numberBucket(0.25), 'Carat')
                  .apply('Count', facet('diamonds').count())
                  .sort('$Count', 'descending')
                  .limit(3)
              )
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
          {
            "fieldName": "tax"
            "name": "_sd_0"
            "type": "doubleSum"
          }
          {
            "aggregator": {
              "fieldName": "price"
              "name": "PriceGoodCut"
              "type": "doubleSum"
            }
            "filter": {
              "dimension": "cut"
              "type": "selector"
              "value": "good"
            }
            "name": "PriceGoodCut"
            "type": "filtered"
          }
        ],
        "postAggregations": [
          {
            "fields": [
              {
                "fieldName": "TotalPrice"
                "type": "fieldAccess"
              }
              {
                "type": "constant"
                "value": 2
              }
            ]
            "fn": "*"
            "name": "PriceTimes2"
            "type": "arithmetic"
          }
          {
            "fields": [
              {
                "fieldName": "TotalPrice"
                "type": "fieldAccess"
              }
              {
                "fieldName": "_sd_0"
                "type": "fieldAccess"
              }
              {
                "type": "constant"
                "value": 1
              }
            ]
            "fn": "*"
            "name": "PriceAndTax"
            "type": "arithmetic"
          }
        ],
        "dataSource": "diamonds"
        "filter": {
          "dimension": "color"
          "type": "selector"
          "value": "D"
        }
        "granularity": "all"
        "intervals": ["2015-03-12/2015-03-19"]
        "queryType": "timeseries"
      }
      # -----------------
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
        "intervals": ["2015-03-12/2015-03-19"]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 2
      }
      # -----------------
      {
        "aggregations": [
          {
            "fieldName": "price"
            "name": "TotalPrice"
            "type": "doubleSum"
          }
        ]
        "dataSource": "diamonds"
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
        "granularity": {
          "period": "P1D"
          "timeZone": "America/Los_Angeles"
          "type": "period"
        }
        "intervals": ["2015-03-12/2015-03-19"]
        "queryType": "timeseries"
      }
      # -----------------
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
        "intervals": ["2015-03-13T07/2015-03-14T07"]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 3
      }
    ])
