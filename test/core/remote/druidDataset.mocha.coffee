{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{ druidRequester } = require('facetjs-druid-requester')

facet = require('../../../build/facet')
{ Expression, Dataset, TimeRange } = facet.core

info = require('../../info')

druidPass = druidRequester({
  host: info.druidHost
})

describe "DruidDataset actually", ->
  it "works in advanced case", (testComplete) ->
    context = {
      wiki: Dataset.fromJS({
        source: 'druid',
        dataSource: 'wikipedia_editstream',
        timeAttribute: 'time',
        forceInterval: true,
        approximate: true,
        context: null
        attributes: {
          time: { type: 'TIME' }
          language: { type: 'STRING' }
          page: { type: 'STRING' }
          added: { type: 'NUMBER' }
        }
        filter: facet('time').in(TimeRange.fromJS({
          start: new Date("2013-02-26T00:00:00Z")
          end: new Date("2013-02-27T00:00:00Z")
        }))
      })
    }

    ex = facet()
      .def("wiki", facet('wiki').filter(facet("language").is('en')))
      .apply('Count', '$wiki.count()')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Cuts',
        facet("wiki").split("$page", 'Page')
          .apply('Count', '$wiki.count()')
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            facet("diamonds").split(facet("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
              .apply('TotalPrice', facet('diamonds').sum('$price'))
              .sort('$Timestamp', 'ascending')
#             .limit(10)
#             .apply('Carats',
#               facet("diamonds").split(facet("carat").numberBucket(0.25), 'Carat')
#                 .apply('Count', facet('diamonds').count())
#                 .sort('$Count', 'descending')
#                 .limit(3)
#             )
          )
      )

    ex.compute(context, druidPass).then((result) ->
      expect(result.toJS()).to.deep.equal([
        {
          "Count": 308675
          "TotalAdded": 41412583
          "Cuts": [
            {
              "Count": 124
              "Page": "Wikipedia:Administrator_intervention_against_vandalism"
            }
            {
              "Count": 88
              "Page": "Wikipedia:Reference_desk/Science"
            }
          ]
        }
      ])
      testComplete()
    ).done()
