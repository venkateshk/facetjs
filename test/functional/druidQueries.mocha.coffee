{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{ druidRequester } = require('facetjs-druid-requester')

facet = require('../../build/facet')
{ Expression, Dataset, TimeRange } = facet.core

info = require('../info')

druidPass = druidRequester({
  host: info.druidHost
})

describe "DruidDataset actually", ->
  @timeout(5000);

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
        requester: druidPass
      })
    }

    ex = facet()
      .def("wiki", facet('wiki').filter(facet("language").is('en')))
      .apply('Count', '$wiki.count()')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Pages',
        facet("wiki").split("$page", 'Page')
          .apply('Count', '$wiki.count()')
          .sort('$Count', 'descending')
          .limit(2)
          .apply('Time',
            facet("wiki").split(facet("time").timeBucket('PT1H', 'America/Los_Angeles'), 'Timestamp')
              .apply('TotalAdded', '$wiki.sum($added)')
              .sort('$Timestamp', 'ascending')
              .limit(3)
          )
      )
#      .apply('PagesHaving',
#        facet("wiki").split("$page", 'Page')
#          .apply('Count', '$wiki.count()')
#          .sort('$Count', 'descending')
#          .filter(facet('Count').lessThan(30))
#          .limit(100)
#      )

    ex.compute(context).then((result) ->
      expect(result.toJS()).to.deep.equal([
        {
          "Count": 308675
          "TotalAdded": 41412583
          "Pages": [
            {
              "Count": 124
              "Page": "Wikipedia:Administrator_intervention_against_vandalism"
              "Time": [
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T01:00:00.000Z')
                    "start": new Date('2013-02-26T00:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 692
                }
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T02:00:00.000Z')
                    "start": new Date('2013-02-26T01:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 1370
                }
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T03:00:00.000Z')
                    "start": new Date('2013-02-26T02:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 945
                }
              ]
            }
            {
              "Count": 88
              "Page": "Wikipedia:Reference_desk/Science"
              "Time": [
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T01:00:00.000Z')
                    "start": new Date('2013-02-26T00:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 1978
                }
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T02:00:00.000Z')
                    "start": new Date('2013-02-26T01:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 4070
                }
                {
                  "Timestamp": {
                    "end": new Date('2013-02-26T03:00:00.000Z')
                    "start": new Date('2013-02-26T02:00:00.000Z')
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 1301
                }
              ]
            }
          ]
        }
      ])
      testComplete()
    ).done()
