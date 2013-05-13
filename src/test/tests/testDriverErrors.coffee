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
    it "should produce the same result", -> {
      "query not supplied": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "query not supplied"
        query: null
      }

      "invalid query 1": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid query"
        query: {}
      }

      "invalid query 2": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid query"
        query: "poo"
      }

      "bad command": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "unrecognizable command"
        query: [
          'blah'
        ]
      }

      "no operation in command": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "operation not defined"
        query: [
          {}
        ]
      }

      "invalid operation in command": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid operation"
        query: [
          { operation: ['wtf?'] }
        ]
      }

      "unknown operation in command": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "unknown operation 'poo'"
        query: [
          { operation: 'poo' }
        ]
      }
    }

  describe "filters", ->
    it "should produce the same result", -> {
      "missing type": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "type not defined in filter"
        query: [
          { operation: 'filter' }
        ]
      }

      "invalid type in filter": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid type in filter"
        query: [
          { operation: 'filter', type: ['wtf?'] }
        ]
      }

      # "unknown type in filter": testError {
      #   drivers: ['simple', 'mySql', 'druid']
      #   error: "filter type 'poo' not defined"
      #   query: [
      #     { operation: 'filter', type: 'poo' }
      #   ]
      # }
    }

  describe "splits", ->
    it "should produce the same result", -> {
      "missing name": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "name not defined in split"
        query: [
          { operation: 'split' }
        ]
      }

      "bad name": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid name in split"
        query: [
          { operation: 'split', name: ["wtf?"] }
        ]
      }
    }

  describe "applies", ->
    it "should produce the same result", -> {
      "missing name": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "name not defined in apply"
        query: [
          { operation: 'apply' }
        ]
      }

      "bad name": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "invalid name in apply"
        query: [
          { operation: 'apply', name: ["wtf?"] }
        ]
      }
    }

  describe "combines", ->
    it "should produce the same result", -> {
      "combine without split": testError {
        drivers: ['simple', 'mySql', 'druid']
        error: "combine called without split"
        query: [
          { operation: 'combine' }
        ]
      }

      "missing combine": testError {
        drivers: ['mySql', 'druid'] # 'simple',
        error: "combine not defined in combine"
        query: [
          { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
          { operation: 'apply', name: 'Count', aggregate: 'count' }
          { operation: 'combine' }
        ]
      }
    }

