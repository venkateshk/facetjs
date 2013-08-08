chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../build/query')

sqlRequester = require('../../build/mySqlRequester')
sqlDriver = require('../../build/sqlDriver')

verbose = false

describe "SQL driver", ->
  #@timeout(40 * 1000)

  describe "should work when getting back []", ->
    emptyRequester = (query, callback) ->
      callback(null, [])
      return

    emptyDriver = sqlDriver({
      requester: emptyRequester
      table: 'blah'
      filters: null
    })

    describe "should return null correctly on an all query", ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      it "should work with [] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result).to.deep.equal({})
          done()
          return

    describe "should return null correctly on a topN query", ->
      query = new FacetQuery([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ])

      it "should work with [] return", (done) ->
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
      filter: FacetFilter.fromSpec({
        type: 'is'
        attribute: 'color'
        value: 'E'
      })
    })

    it "should get back the same result", (done) ->
      noFilter {
        query: new FacetQuery([
          { operation: 'filter', type: 'is', attribute: 'color', value: 'E' }
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ])
      }, (err, noFilterRes) ->
        expect(noFilterRes).to.be.an('object')
        withFilter {
          query: new FacetQuery([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        }, (err, withFilterRes) ->
          expect(withFilterRes).to.be.an('object')
          expect(noFilterRes).to.deep.equal(withFilterRes)
          done()

