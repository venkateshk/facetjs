chai = require("chai")
expect = chai.expect
utils = require('../utils')

sqlRequester = require('../../target/mySqlRequester')
sqlDriver = require('../../target/sqlDriver')

verbose = false

describe "SQL driver tests", ->
  #@timeout(40 * 1000)

  describe "should work when getting back [] and [{result:[]}]", ->
    nullRequester = (query, callback) ->
      callback(null, [])
      return

    nullDriver = sqlDriver({
      requester: nullRequester
      table: 'blah'
      filters: null
    })

    emptyRequester = (query, callback) ->
      callback(null, [])
      return

    emptyDriver = sqlDriver({
      requester: nullRequester
      table: 'blah'
      filters: null
    })

    describe "should return null correctly on an all query", ->
      query = [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ]

      it "should work with [] return", (done) ->
        nullDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result).to.deep.equal({})
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result).to.deep.equal({})
          done()
          return

    describe "should return null correctly on a topN query", ->
      query = [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ]

      it "should work with [] return", (done) ->
        nullDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result).to.deep.equal({})
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result).to.deep.equal({})
          done()

  describe "should work with driver level filter", ->
    sqlPass = sqlRequester({
      host: 'localhost'
      database: 'facet'
      user: 'facet_user'
      password: 'HadleyWickham'
    })

    noFilter = sqlDriver({
      requester: sqlPass
      table: 'diamonds'
      filter: null
    })

    withFilter = sqlDriver({
      requester: sqlPass
      table: 'diamonds'
      filter: { type: 'is', attribute: 'color', value: 'E' }
    })

    it "should get back the same result", (done) ->
      noFilter {
        query: [
          { operation: 'filter', type: 'is', attribute: 'color', value: 'E' }
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ]
      }, (err, noFilterRes) ->
        expect(noFilterRes).to.be.an('object')
        withFilter {
          query: [
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ]
        }, (err, withFilterRes) ->
          expect(withFilterRes).to.be.an('object')
          expect(noFilterRes).to.deep.equal(withFilterRes)
          done()

