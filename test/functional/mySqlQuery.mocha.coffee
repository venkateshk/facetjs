{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{ mySqlRequester } = require('facetjs-mysql-requester')

facet = require('../../build/facet')
{ Expression, Dataset, TimeRange } = facet.core

info = require('../info')

mySqlPass = mySqlRequester({
  host: info.mySqlHost
  database: info.mySqlDatabase
  user: info.mySqlUser
  password: info.mySqlPassword
})

describe "MySQLDataset actually", ->
  @timeout(10000);

  it "works in advanced case", (testComplete) ->
    context = {
      wiki: Dataset.fromJS({
        source: 'mysql'
        table: 'wiki_day_agg'
        attributes: {
          time: { type: 'TIME' }
          language: { type: 'STRING' }
          page: { type: 'STRING' }
          added: { type: 'NUMBER' }
        }
        requester: mySqlPass
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
            facet("wiki").split(facet("time").timeBucket('PT1H', 'Etc/UTC'), 'Timestamp')
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

  it "works with introspection", (testComplete) ->
    context = {
      wiki: Dataset.fromJS({
        source: 'mysql'
        table: 'wiki_day_agg'
        requester: mySqlPass
      })
    }

    ex = facet()
      .def("wiki", facet('wiki').filter(facet("language").is('en')))
      .apply('Count', '$wiki.count()')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Time',
        facet("wiki").split(facet("time").timeBucket('PT1H', 'Etc/UTC'), 'Timestamp')
          .apply('TotalAdded', '$wiki.sum($added)')
          .sort('$Timestamp', 'ascending')
          .limit(3)
          .apply('Pages',
            facet("wiki").split("$page", 'Page')
              .apply('Count', '$wiki.count()')
              .sort('$Count', 'descending')
              .limit(2)
          )
      )

    ex.compute(context).then((result) ->
      expect(result.toJS()).to.deep.equal([
        {
          "Count": 308675
          "Time": [
            {
              "Timestamp": {
                "end": new Date("2013-02-26T01:00:00.000Z")
                "start": new Date("2013-02-26T00:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 2149342
              "Pages": [
                {
                  "Count": 6
                  "Page": "Wikipedia:In_the_news/Candidates"
                }
                {
                  "Count": 5
                  "Page": "Hercules"
                }
              ]
            }
            {
              "Timestamp": {
                "end": new Date("2013-02-26T02:00:00.000Z")
                "start": new Date("2013-02-26T01:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 1717907
              "Pages": [
                {
                  "Count": 6
                  "Page": "Wikipedia:Requests_for_page_protection"
                }
                {
                  "Count": 5
                  "Page": "Taming_of_the_Shrew_Act_3"
                }
              ]
            }
            {
              "Timestamp": {
                "end": new Date("2013-02-26T03:00:00.000Z")
                "start": new Date("2013-02-26T02:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 1258761
              "Pages": [
                {
                  "Count": 6
                  "Page": "Wikipedia:Administrators'_noticeboard/Incidents"
                }
                {
                  "Count": 5
                  "Page": "Talk:Contemporary_Christian_music"
                }
              ]
            }
          ]
          "TotalAdded": 41412583
        }
      ])
      testComplete()
    ).done()
