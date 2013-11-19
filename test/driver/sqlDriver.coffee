chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../build/query')

sqlRequester = require('../../build/mySqlRequester')
sqlDriver = require('../../build/sqlDriver')

verbose = false

sqlPass = sqlRequester({
  host: 'localhost'
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

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

    describe "should return null correctly on an empty split", ->
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
        expect(err).to.be.null
        expect(noFilterRes).to.be.an('object')
        withFilter {
          query: new FacetQuery([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        }, (err, withFilterRes) ->
          expect(withFilterRes).to.be.an('object')
          expect(noFilterRes).to.deep.equal(withFilterRes)
          done()

  describe "should work with nothingness", ->
    diamondsDriver = sqlDriver({
      requester: sqlPass
      table: 'diamonds'
      filter: null
    })

    it "does handles nothingness", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
      ]
      diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.equal(null)
        expect(result).to.deep.equal({
          "prop": {}
        })
        done()

    it "deals well with empty results", ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        done()



