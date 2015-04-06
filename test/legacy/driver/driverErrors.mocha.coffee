{ expect } = require("chai")

utils = require('../../utils')

{ druidRequesterFactory } = require('facetjs-druid-requester')
{ mySqlRequesterFactory } = require('facetjs-mysql-requester')

facet = require("../../../build/facet")
{ FacetFilter, nativeDriver, mySqlDriver, druidDriver } = facet.legacy

info = require('../../info')

# Set up drivers
driverFns = {}

# Native
diamondsData = require('../../../data/diamonds.js')
driverFns.native = nativeDriver(diamondsData)

# MySQL
mySqlRequester = mySqlRequesterFactory({
  host: info.mySqlHost
  database: info.mySqlDatabase
  user: info.mySqlUser
  password: info.mySqlPassword
})

driverFns.mySql = mySqlDriver({
  requester: mySqlRequester
  table: 'wiki_day_agg'
  filters: null
})

# Druid
druidRequester = druidRequesterFactory({
  host: info.druidHost
})

driverFns.druid = druidDriver({
  requester: druidRequester
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  filter: FacetFilter.fromJS({
    type: 'within'
    attribute: 'time'
    range: [
      new Date("2013-02-26T00:00:00Z")
      new Date("2013-02-27T00:00:00Z")
    ]
  })
})

testError = utils.makeErrorTest(driverFns)

describe "Error compatibility", ->
  describe "basics", ->
    it "request not supplied", testError {
      drivers: ['native', 'mySql', 'druid']
      error: "request not supplied"
      request: null
    }

    it "query not supplied", testError {
      drivers: ['native', 'mySql', 'druid']
      error: "query not supplied"
      request: {}
    }

    it "invalid query 1", testError {
      drivers: ['native', 'mySql', 'druid']
      error: "query must be a FacetQuery"
      request: {
        query: {}
      }
    }

    it "invalid query 2", testError {
      drivers: ['native', 'mySql', 'druid']
      error: "query must be a FacetQuery"
      request: {
        query: "poo"
      }
    }

