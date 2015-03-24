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
          count: { type: 'NUMBER' }
        }
        requester: mySqlPass
      })
    }

    ex = facet()
      .def("wiki", facet('wiki').filter(facet("language").is('en')))
      .apply('Count', '$wiki.sum($count)')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Pages',
        facet("wiki").split("$page", 'Page')
          .apply('Count', '$wiki.sum($count)')
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
#          .apply('Count', '$wiki.sum($count)')
#          .sort('$Count', 'descending')
#          .filter(facet('Count').lessThan(30))
#          .limit(100)
#      )

    ex.compute(context).then((result) ->
      expect(result.toJS()).to.deep.equal([
        {
          "Count": 334129
          "Pages": [
            {
              "Count": 626
              "Page": "User:Addbot/log/wikidata"
              "Time": [
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T01:00:00.000Z")
                    "start": new Date("2013-02-26T00:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 159582
                }
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T02:00:00.000Z")
                    "start": new Date("2013-02-26T01:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 134436
                }
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T03:00:00.000Z")
                    "start": new Date("2013-02-26T02:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 276
                }
              ]
            }
            {
              "Count": 329
              "Page": "User:Legobot/Wikidata/General"
              "Time": [
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T01:00:00.000Z")
                    "start": new Date("2013-02-26T00:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 0
                }
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T02:00:00.000Z")
                    "start": new Date("2013-02-26T01:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 0
                }
                {
                  "Timestamp": {
                    "end": new Date("2013-02-26T03:00:00.000Z")
                    "start": new Date("2013-02-26T02:00:00.000Z")
                    "type": "TIME_RANGE"
                  }
                  "TotalAdded": 0
                }
              ]
            }
          ]
          "TotalAdded": 41412583
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
      .apply('Count', '$wiki.sum($count)')
      .apply('TotalAdded', '$wiki.sum($added)')
      .apply('Time',
        facet("wiki").split(facet("time").timeBucket('PT1H', 'Etc/UTC'), 'Timestamp')
          .apply('TotalAdded', '$wiki.sum($added)')
          .sort('$Timestamp', 'ascending')
          .limit(3)
          .apply('Pages',
            facet("wiki").split("$page", 'Page')
              .apply('Count', '$wiki.sum($count)')
              .sort('$Count', 'descending')
              .limit(2)
          )
      )

    ex.compute(context).then((result) ->
      expect(result.toJS()).to.deep.equal([
        {
          "Count": 334129
          "Time": [
            {
              "Pages": [
                {
                  "Count": 130
                  "Page": "User:Addbot/log/wikidata"
                }
                {
                  "Count": 31
                  "Page": "Wikipedia:Categories_for_discussion/Speedy"
                }
              ]
              "Timestamp": {
                "end": new Date("2013-02-26T01:00:00.000Z")
                "start": new Date("2013-02-26T00:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 2149342
            }
            {
              "Pages": [
                {
                  "Count": 121
                  "Page": "User:Addbot/log/wikidata"
                }
                {
                  "Count": 34
                  "Page": "Ahmed_Elkady"
                }
              ]
              "Timestamp": {
                "end": new Date("2013-02-26T02:00:00.000Z")
                "start": new Date("2013-02-26T01:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 1717907
            }
            {
              "Pages": [
                {
                  "Count": 22
                  "Page": "User:Libsbml/sandbox"
                }
                {
                  "Count": 20
                  "Page": "The_Biggest_Loser:_Challenge_America"
                }
              ]
              "Timestamp": {
                "end": new Date("2013-02-26T03:00:00.000Z")
                "start": new Date("2013-02-26T02:00:00.000Z")
                "type": "TIME_RANGE"
              }
              "TotalAdded": 1258761
            }
          ]
          "TotalAdded": 41412583
        }
      ])
      testComplete()
    ).done()
