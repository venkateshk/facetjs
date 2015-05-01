{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../build/facet')
{ Expression, Dataset, TimeRange, $ } = facet

context = {
  diamonds: Dataset.fromJS({
    source: 'druid',
    dataSource: 'diamonds',
    timeAttribute: 'time',
    context: null
    attributes: {
      time: { type: 'TIME' }
      color: { type: 'STRING' }
      cut: { type: 'STRING' }
      tags: { type: 'SET/STRING' }
      carat: { type: 'NUMBER' }
      height_bucket: { special: 'range', separator: ';', rangeSize: 0.05, digitsAfterDecimal: 2 }
      price: { type: 'NUMBER', filterable: false, splitable: false }
      tax: { type: 'NUMBER', filterable: false, splitable: false }
      unique_views: { special: 'unique', filterable: false, splitable: false }
    }
    filter: $("time").in({
      start: new Date('2015-03-12T00:00:00')
      end:   new Date('2015-03-19T00:00:00')
    })
  })
}

describe "simulate Druid", ->
  it "works in advanced case", ->
    ex = $()
      .def("diamonds", $('diamonds').filter($("color").is('D')))
      .apply('Count', '$diamonds.count()')
      .apply('TotalPrice', '$diamonds.sum($price)')
      .apply('PriceTimes2', '$diamonds.sum($price) * 2')
      .apply('PriceMinusTax', '$diamonds.sum($price) - $diamonds.sum($tax)')
      .apply('Crazy', '$diamonds.sum($price) - $diamonds.sum($tax) + 10 - $diamonds.sum($carat)')
      .apply('PriceAndTax', '$diamonds.sum($price) * $diamonds.sum($tax)')
      .apply('PriceGoodCut', $('diamonds').filter($('cut').is('good')).sum('$price'))
      .apply('Cuts',
        $("diamonds").split("$cut", 'Cut')
          .apply('Count', $('diamonds').count())
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            $("diamonds").split($("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
              .apply('TotalPrice', $('diamonds').sum('$price'))
              .sort('$Timestamp', 'ascending')
              #.limit(10)
              .apply('Carats',
                $("diamonds").split($("carat").numberBucket(0.25), 'Carat')
                  .apply('Count', $('diamonds').count())
                  .sort('$Count', 'descending')
                  .limit(3)
              )
          )
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "fieldName": "tax"
            "name": "_sd_0"
            "type": "doubleSum"
          }
          {
            "fieldName": "carat"
            "name": "_sd_1"
            "type": "doubleSum"
          }
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
        ]
        "dataSource": "diamonds"
        "filter": {
          "dimension": "color"
          "type": "selector"
          "value": "D"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
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
            ]
            "fn": "-"
            "name": "PriceMinusTax"
            "type": "arithmetic"
          }
          {
            "fields": [
              {
                "fields": [
                  {
                    "fieldName": "TotalPrice"
                    "type": "fieldAccess"
                  }
                  {
                    "type": "constant"
                    "value": 10
                  }
                ]
                "fn": "+"
                "type": "arithmetic"
              }
              {
                "fields": [
                  {
                    "fieldName": "_sd_0"
                    "type": "fieldAccess"
                  }
                  {
                    "fieldName": "_sd_1"
                    "type": "fieldAccess"
                  }
                ]
                "fn": "+"
                "type": "arithmetic"
              }
            ]
            "fn": "-"
            "name": "Crazy"
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
            ]
            "fn": "*"
            "name": "PriceAndTax"
            "type": "arithmetic"
          }
        ]
        "queryType": "timeseries"
      }
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
          "2015-03-12/2015-03-19"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 2
      }
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
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "queryType": "timeseries"
      }
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "extractionFn": {
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
          "2015-03-13T07/2015-03-14T07"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 3
      }
    ])

  it "works with having filter", ->
    ex = $("diamonds").split("$cut", 'Cut')
      .apply('Count', $('diamonds').count())
      .sort('$Count', 'descending')
      .filter($('Count').greaterThan(100))
      .limit(10)

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimensions": [
          {
            "dimension": "cut"
            "outputName": "Cut"
            "type": "default"
          }
        ]
        "granularity": "all"
        "having": {
          "aggregation": "Count"
          "type": "greaterThan"
          "value": 100
        }
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "limitSpec": {
          "columns": [
            {
              "dimension": "Count"
              "direction": "descending"
            }
          ]
          "limit": 10
          "type": "default"
        }
        "queryType": "groupBy"
      }
    ])

  it "works with range bucket", ->
    ex = $()
      .apply('HeightBuckets',
        $("diamonds").split("$height_bucket", 'HeightBucket')
          .apply('Count', $('diamonds').count())
          .sort('$Count', 'descending')
          .limit(10)
      )
      .apply('HeightUpBuckets',
        $("diamonds").split($('height_bucket').numberBucket(2, 0.5), 'HeightBucket')
          .apply('Count', $('diamonds').count())
          .sort('$Count', 'descending')
          .limit(10)
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "extractionFn": {
            "function": "function(d) {\nvar m = d.match(/^((?:-?[1-9]\\d*|0)\\.\\d{2});((?:-?[1-9]\\d*|0)\\.\\d{2})$/);\nif(!m) return 'null';\nvar s = +m[1];\nif(!(Math.abs(+m[2] - s - 0.05) < 1e-6)) return 'null'; \nvar parts = String(Math.abs(s)).split('.');\nparts[0] = ('000000000' + parts[0]).substr(-10);\nreturn (start < 0 ?'-':'') + parts.join('.');\n}"
            "type": "javascript"
          }
          "dimension": "height_bucket"
          "outputName": "HeightBucket"
          "type": "extraction"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 10
      }
      # ---------------------
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "extractionFn": {
            "function": "function(d) {\nvar m = d.match(/^((?:-?[1-9]\\d*|0)\\.\\d{2});((?:-?[1-9]\\d*|0)\\.\\d{2})$/);\nif(!m) return 'null';\nvar s = +m[1];\nif(!(Math.abs(+m[2] - s - 0.05) < 1e-6)) return 'null'; s=Math.floor((s - 0.5) / 2) * 2 + 0.5;\nvar parts = String(Math.abs(s)).split('.');\nparts[0] = ('000000000' + parts[0]).substr(-10);\nreturn (start < 0 ?'-':'') + parts.join('.');\n}"
            "type": "javascript"
          }
          "dimension": "height_bucket"
          "outputName": "HeightBucket"
          "type": "extraction"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 10
      }
    ])

  it "makes a timeBoundary query", ->
    ex = $()
      .apply('maximumTime', '$diamonds.max($time)')
      .apply('minimumTime', '$diamonds.min($time)')

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "dataSource": "diamonds"
        "queryType": "timeBoundary"
      }
    ])

  it "makes a timeBoundary query (maxTime only)", ->
    ex = $()
      .apply('maximumTime', '$diamonds.max($time)')

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "dataSource": "diamonds"
        "queryType": "timeBoundary"
        "bound": "maxTime"
      }
    ])

  it "makes a timeBoundary query (minTime only)", ->
    ex = $()
      .apply('minimumTime', '$diamonds.min($time)')

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "dataSource": "diamonds"
        "queryType": "timeBoundary"
        "bound": "minTime"
      }
    ])

  it "makes a topN with a timePart dim extraction fn", ->
    ex = $("diamonds").split($("time").timePart('SECOND_OF_DAY', 'Etc/UTC'), 'Time')
      .apply('Count', $('diamonds').count())
      .sort('$Count', 'descending')
      .limit(10)

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "__time"
          "extractionFn": {
            "format": "H'*60+'m'*60+'s"
            "locale": "en-US"
            "timeZone": "Etc/UTC"
            "type": "timeFormat"
          }
          "outputName": "Time"
          "type": "extraction"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 10
      }
    ])

  it "makes a filter on timePart", ->
    ex = $("diamonds").filter(
      $("time").timePart('HOUR_OF_DAY', 'Etc/UTC').in([3, 4, 10]).and($("time").in([
          TimeRange.fromJS({ start: new Date('2015-03-12T00:00:00'), end: new Date('2015-03-15T00:00:00') })
          TimeRange.fromJS({ start: new Date('2015-03-16T00:00:00'), end: new Date('2015-03-18T00:00:00') })
        ]
      ))
    ).split("$color", 'Color')
      .apply('Count', $('diamonds').count())
      .sort('$Count', 'descending')
      .limit(10)

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "color"
          "outputName": "Color"
          "type": "default"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12T03/2015-03-12T05"
          "2015-03-12T10/2015-03-12T11"
          "2015-03-13T03/2015-03-13T05"
          "2015-03-13T10/2015-03-13T11"
          "2015-03-14T03/2015-03-14T05"
          "2015-03-14T10/2015-03-14T11"

          "2015-03-16T03/2015-03-16T05"
          "2015-03-16T10/2015-03-16T11"
          "2015-03-17T03/2015-03-17T05"
          "2015-03-17T10/2015-03-17T11"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 10
      }
    ])

  it "splits on timePart with sub split", ->
    ex = $("diamonds").split($("time").timePart('HOUR_OF_DAY', 'Etc/UTC'), 'hourOfDay')
      .apply('Count', '$diamonds.count()')
      .sort('$Count', 'descending')
      .limit(3)
      .apply('Colors'
        $("diamonds").split("$color", 'Color')
          .apply('Count', $('diamonds').count())
          .sort('$Count', 'descending')
          .limit(10)
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "__time"
          "extractionFn": {
            "format": "H"
            "locale": "en-US"
            "timeZone": "Etc/UTC"
            "type": "timeFormat"
          }
          "outputName": "hourOfDay"
          "type": "extraction"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 3
      }
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "color"
          "outputName": "Color"
          "type": "default"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12T04/2015-03-12T05"
          "2015-03-13T04/2015-03-13T05"
          "2015-03-14T04/2015-03-14T05"
          "2015-03-15T04/2015-03-15T05"
          "2015-03-16T04/2015-03-16T05"
          "2015-03-17T04/2015-03-17T05"
          "2015-03-18T04/2015-03-18T05"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 10
      }
    ])

  it "works without a sort defined", ->
    ex = $()
      .apply('topN',
        $("diamonds").split("$color", 'Color')
          .apply('Count', $('diamonds').count())
          .limit(10)
      )
      .apply('timeseries',
        $("diamonds").split($("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
          .apply('Count', $('diamonds').count())
          .limit(10)
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "color"
          "outputName": "Color"
          "type": "default"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "metric": {
          "type": "lexicographic"
        }
        "queryType": "topN"
        "threshold": 10
      }
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "granularity": {
          "period": "P1D"
          "timeZone": "America/Los_Angeles"
          "type": "period"
        }
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "queryType": "timeseries"
      }
    ])

  it "works with no attributes in time split dataset", ->
    # Unit test added thanks for bug found by Venkatesh Kavuluri
    # https://groups.google.com/forum/#!topic/facetjs/uM9SldjRuhY
    ex = $()
      .apply('ByHour',
        $('diamonds').split($("time").timeBucket('PT1H', 'Etc/UTC'), 'TimeByHour')
          .sort('$TimeByHour', 'ascending')
          .apply('Users',
            $('diamonds').split('$color', 'Color')
              .apply('Count', $('diamonds').count())
              .sort('$Count', 'descending')
              .limit(3)
          )
      )

    expect(ex.simulateQueryPlan(context)).to.deep.equal([
      {
        "aggregations": [
          {
            "name": "_dummy"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "granularity": {
          "period": "PT1H"
          "timeZone": "Etc/UTC"
          "type": "period"
        }
        "intervals": [
          "2015-03-12/2015-03-19"
        ]
        "queryType": "timeseries"
      }
      {
        "aggregations": [
          {
            "name": "Count"
            "type": "count"
          }
        ]
        "dataSource": "diamonds"
        "dimension": {
          "dimension": "color"
          "outputName": "Color"
          "type": "default"
        }
        "granularity": "all"
        "intervals": [
          "2015-03-14/2015-03-14T01"
        ]
        "metric": "Count"
        "queryType": "topN"
        "threshold": 3
      }
    ])
