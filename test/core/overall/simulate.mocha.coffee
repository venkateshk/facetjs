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
        }
      })
      timeFilter: TimeRange.fromJS({
        start: new Date('2015-03-14T00:00:00')
        end:   new Date('2015-03-21T00:00:00')
      })
    }

    ex = facet()
      .def("diamonds", facet('diamonds').filter(facet("color").is('D').and(facet("time").in('$timeFilter'))))
      .apply('Count', facet('diamonds').count())
      .apply('TotalPrice', facet('diamonds').sum('$price'))
      .apply('Cuts',
        facet("diamonds").split("$cut", 'Cut')
          .apply('Count', facet('diamonds').count())
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            facet("diamonds").split(facet("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
              .apply('TotalPrice', facet('diamonds').sum('$price'))
              .sort('$Timestamp', 'ascending')
              .limit(10)
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
        ]
        "dataSource": "diamonds"
        "filter": {
          "dimension": "color"
          "type": "selector"
          "value": "D"
        }
        "granularity": "all"
        "intervals": ["2015-03-14/2015-03-21"]
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
        "intervals": ["2015-03-14/2015-03-21"]
        "queryType": "topN"
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
        "intervals": ["2015-03-14/2015-03-21"]
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
        "granularity": "all"
        "intervals": ["1000-01-01/1000-01-02"] # ToDo: WTF?!
        "queryType": "topN"
      }
    ])
