{ expect } = require("chai")
utils = require('../../utils')

Q = require('q')

{ mySqlRequester } = require('facetjs-mysql-requester')

facet = require("../../../build/facet")
{ FacetQuery, FacetFilter, mySqlDriver } = facet.legacy

info = require('../../info')

verbose = false

mySqlPass = mySqlRequester({
  host: info.mySqlHost
  database: info.mySqlDatabase
  user: info.mySqlUser
  password: info.mySqlPassword
})

describe "SQL driver", ->
  #@timeout(40 * 1000)

  describe "introspects", ->
    diamondsDriver = mySqlDriver({
      requester: mySqlPass
      table: 'wiki_day_agg'
    })

    it "works", (testComplete) ->
      diamondsDriver.introspect(null).then((attributes) ->
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
        testComplete()
      ).done()


  describe "should work when getting back []", ->
    emptyRequester = -> Q([])

    emptyDriver = mySqlDriver({
      requester: emptyRequester
      table: 'blah'
      filters: null
    })

    describe "should return null correctly on an all query", ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      it "should work with [] return", (testComplete) ->
        emptyDriver({ query }).then((result) ->
          expect(result.toJS()).to.deep.equal({
            prop: {
              "Count": 0
            }
          })
          testComplete()
        ).done()

    describe "should return null correctly on an empty split", ->
      query = new FacetQuery([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ])

      it "should work with [] return", (testComplete) ->
        emptyDriver({ query }).then((result) ->
          expect(result.toJS()).to.deep.equal({
            prop: {}
            splits: []
          })
          testComplete()
        ).done()

  describe "should work with driver level filter", ->
    noFilter = mySqlDriver({
      requester: mySqlPass
      table: 'diamonds'
      filter: null
    })

    withFilter = mySqlDriver({
      requester: mySqlPass
      table: 'diamonds'
      filter: FacetFilter.fromJS({
        type: 'is'
        attribute: 'color'
        value: 'E'
      })
    })

    it "should get back the same result", (testComplete) ->
      noFilterRes = null
      noFilter({
        query: new FacetQuery([
          { operation: 'filter', type: 'is', attribute: 'color', value: 'E' }
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ])
      }).then((_noFilterRes) ->
        noFilterRes = _noFilterRes
        return withFilter({
          query: new FacetQuery([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        })
      ).then((withFilterRes) ->
        expect(noFilterRes.valueOf()).to.deep.equal(withFilterRes.valueOf())
        testComplete()
      ).done()

  describe "should work with nothingness", ->
    diamondsDriver = mySqlDriver({
      requester: mySqlPass
      table: 'diamonds'
      filter: null
    })

    it "does handles nothingness", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
      ]
      diamondsDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {}
        })
        testComplete()
      ).done()

    it "deals well with empty results", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      diamondsDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        testComplete()
      ).done()

    it "deals well with empty results", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }

        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }
      ]
      diamondsDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {
            Count: 0
          }
          splits: []
        })
        testComplete()
      ).done()
