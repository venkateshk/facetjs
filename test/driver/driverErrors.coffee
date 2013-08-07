chai = require("chai")
expect = chai.expect
utils = require('../utils')

druidRequester = require('../../target/druidRequester')
sqlRequester = require('../../target/mySqlRequester')

simpleDriver = require('../../target/simpleDriver')
sqlDriver = require('../../target/sqlDriver')
druidDriver = require('../../target/druidDriver')

# Set up drivers
driverFns = {}

# Simple
diamondsData = require('../../data/diamonds.js')
driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = sqlRequester({
  host: 'localhost'
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
  host: '10.60.134.138'
  port: 8080
})

driverFns.druid = druidDriver({
  requester: druidPass
  dataSource: 'wikipedia_editstream'
  timeAttribute: 'time'
  approximate: true
  filter: {
    type: 'within'
    attribute: 'time'
    range: [
      new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
      new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
    ]
  }
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
      error: "invalid query"
      request: {
        query: {}
      }
    }

    it "invalid query 2", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "invalid query"
      request: {
        query: "poo"
      }
    }

