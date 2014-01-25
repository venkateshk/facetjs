chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetFilter} = require('../../src/query')

simpleLocator = require('../../src/locator/simpleLocator')

druidRequester = require('../../src/requester/druidRequester')
sqlRequester = require('../../src/requester/mySqlRequester')

simpleDriver = require('../../src/driver/simpleDriver')
sqlDriver = require('../../src/driver/sqlDriver')
druidDriver = require('../../src/driver/druidDriver')

# Set up drivers
driverFns = {}

# Simple
diamondsData = require('../../data/diamonds.js')
driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  locator: simpleLocator('localhost')
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'wiki_day_agg'
  filters: null
})

# # Druid
druidPass = druidRequester({
  locator: simpleLocator('10.209.98.48')
})

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  filter: FacetFilter.fromSpec({
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
    ]
  })
})

testError = utils.makeErrorTest(driverFns)

describe "Error compat test", ->
  describe "basics", ->
    it "request not supplied", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "request not supplied"
      request: null
    }

    it "query not supplied", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "query not supplied"
      request: {}
    }

    it "invalid query 1", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "query must be a FacetQuery"
      request: {
        query: {}
      }
    }

    it "invalid query 2", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "query must be a FacetQuery"
      request: {
        query: "poo"
      }
    }

