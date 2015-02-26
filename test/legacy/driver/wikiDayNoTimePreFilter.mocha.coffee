{ expect } = require("chai")
utils = require('../../utils')

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{ druidRequester } = require('facetjs-druid-requester')
{ mySqlRequester } = require('facetjs-mysql-requester')

facet = require("../../../build/facet")
{ FacetFilter, nativeDriver, mySqlDriver, druidDriver } = facet.legacy

info = require('../../info')

# Set up drivers
driverFns = {}
verbose = false

# Native
# diamondsData = require('../../build/data/diamonds.js')
# driverFns.native = nativeDriver(diamondsData)

# MySQL
sqlPass = mySqlRequester({
  host: info.mySqlHost
  database: info.mySqlDatabase
  user: info.mySqlUser
  password: info.mySqlPassword
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = mySqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  host: info.druidHost
})

druidPass = utils.wrapVerbose(druidPass, 'Druid') if verbose

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  forceInterval: true
})

testEquality = utils.makeEqualityTest(driverFns)

describe "Wikipedia day dataset (no filter)", ->
  @timeout(40 * 1000)

  describe "non-contagious time", ->
    it "should have the same results for all query", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { attribute: 'language', type: 'is', value: 'en' }
            {
              type: 'or'
              filters: [
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T04:00:00Z"), new Date("2013-02-26T07:00:00Z")] }
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T17:00:00Z"), new Date("2013-02-26T20:00:00Z")] }
              ]
            }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
    }

    it "should have the same results for identity bucket", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { attribute: 'language', type: 'is', value: 'en' }
            {
              type: 'or'
              filters: [
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T04:00:00Z"), new Date("2013-02-26T07:00:00Z")] }
                # Had to remove the third filter because Druid gets it wrong due to topN merging
              ]
            }
          ]
        }
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Added', direction: 'descending' }, limit: 5 }
      ]
    }

    it "should have the same results for timePeriod bucket", testEquality {
      drivers: ['druid', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { attribute: 'language', type: 'is', value: 'en' }
            {
              type: 'or'
              filters: [
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-26T02:00:00Z")] }
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T04:00:00Z"), new Date("2013-02-26T07:00:00Z")] }
                { attribute: 'time', type: 'within', range: [new Date("2013-02-26T17:00:00Z"), new Date("2013-02-26T20:00:00Z")] }
              ]
            }
          ]
        }
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'descending' } }
      ]
    }
