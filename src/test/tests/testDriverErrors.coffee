chai = require("chai")
expect = chai.expect
utils = require('../utils')

druidRequester = require('../../../target/druidRequester')
sqlRequester = require('../../../target/mySqlRequester')

simpleDriver = require('../../../target/simpleDriver')
sqlDriver = require('../../../target/sqlDriver')
druidDriver = require('../../../target/druidDriver')

# Set up drivers
driverFns = {}

# Simple
diamondsData = require('../../../data/diamonds.js')
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

    it "bad command", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "unrecognizable command"
      request: {
        query: [
          'blah'
        ]
      }
    }

    it "no operation in command", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "operation not defined"
      request: {
        query: [
          {}
        ]
      }
    }

    it "invalid operation in command", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "invalid operation"
      request: {
        query: [
          { operation: ['wtf?'] }
        ]
      }
    }

    it "unknown operation in command", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "unknown operation 'poo'"
      request: {
        query: [
          { operation: 'poo' }
        ]
      }
    }


  describe "filters", ->
    it "missing type", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "type not defined in filter"
      request: {
        query: [
          { operation: 'filter' }
        ]
      }
    }

    it "invalid type in filter", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "invalid type in filter"
      request: {
        query: [
          { operation: 'filter', type: ['wtf?'] }
        ]
      }
    }

    #it "unknown type in filter", testError {
    #   drivers: ['simple', 'mySql', 'druid']
    #   error: "filter type 'poo' not defined"
    #   request: {
    #     query: [
    #       { operation: 'filter', type: 'poo' }
    #     ]
    #   }
    # }


  describe "splits", ->
    it "missing name", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "name not defined in split"
      request: {
        query: [
          { operation: 'split' }
        ]
      }
    }

    it "bad name", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "invalid name in split"
      request: {
        query: [
          { operation: 'split', name: ["wtf?"] }
        ]
      }
    }


  describe "applies", ->
    it "missing name", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "name not defined in apply"
      request: {
        query: [
          { operation: 'apply' }
        ]
      }
    }

    it "bad name", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "invalid name in apply"
      request: {
        query: [
          { operation: 'apply', name: ["wtf?"] }
        ]
      }
    }


  describe "combines", ->
    it "combine without split", testError {
      drivers: ['simple', 'mySql', 'druid']
      error: "combine called without split"
      request: {
        query: [
          { operation: 'combine' }
        ]
      }
    }

    it "missing combine", testError {
      drivers: ['mySql', 'druid'] # 'simple',
      error: "combine not defined in combine"
      request: {
        query: [
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
          { operation: 'apply', name: 'Count', aggregate: 'count' }
          { operation: 'combine' }
        ]
      }
    }
