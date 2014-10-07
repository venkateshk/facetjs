chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../src/query')

simpleLocator = require('../../src/locator/simpleLocator')

sqlRequester = require('../../src/requester/mySqlRequester')
sqlDriver = require('../../src/driver/sqlDriver')

verbose = false

sqlPass = sqlRequester({
  locator: simpleLocator('localhost')
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

describe "SQL driver", ->
  #@timeout(40 * 1000)

  describe "introspects", ->
    diamondsDriver = sqlDriver({
      requester: sqlPass
      table: 'wiki_day_agg'
    })

    it "works", (done) ->
      diamondsDriver.introspect null, (err, attributes) ->
        expect(attributes).to.deep.equal([
          {
            "name": "time",
            "time": true
          },
          {
            "name": "page",
            "categorical": true
          },
          {
            "name": "language",
            "categorical": true
          },
          {
            "name": "namespace",
            "categorical": true
          },
          {
            "name": "user",
            "categorical": true
          },
          {
            "name": "robot",
            "numeric": true,
            "integer": true
          },
          {
            "name": "newPage",
            "numeric": true,
            "integer": true
          },
          {
            "name": "geo",
            "categorical": true
          },
          {
            "name": "anonymous",
            "numeric": true,
            "integer": true
          },
          {
            "name": "unpatrolled",
            "numeric": true,
            "integer": true
          },
          {
            "name": "count",
            "numeric": true,
            "integer": true
          },
          {
            "name": "delta",
            "numeric": true
          },
          {
            "name": "added",
            "numeric": true
          },
          {
            "name": "deleted",
            "numeric": true
          }
        ])
        done()


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
          expect(result.valueOf()).to.deep.equal({
            prop: {
              "Count": 0
            }
          })
          done()

    describe "should return null correctly on an empty split", ->
      query = new FacetQuery([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ])

      it "should work with [] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result.valueOf()).to.deep.equal({
            prop: {}
            splits: []
          })
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
      filter: FacetFilter.fromJS({
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
        withFilter {
          query: new FacetQuery([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        }, (err, withFilterRes) ->
          expect(noFilterRes.valueOf()).to.deep.equal(withFilterRes.valueOf())
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
        expect(err).to.not.exist
        expect(result.valueOf()).to.deep.equal({
          prop: {}
        })
        done()

    it "deals well with empty results", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        done()

    it "deals well with empty results", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }

        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }
      ]
      diamondsDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({
          prop: {
            Count: 0
          }
          splits: []
        })
        done()



