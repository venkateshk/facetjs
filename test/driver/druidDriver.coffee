chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../build/query')

druidRequester = require('../../build/druidRequester')
druidDriver = require('../../build/druidDriver')

verbose = false

describe "Druid driver", ->
  @timeout(5 * 1000)

  describe "should work when getting back [] and [{result:[]}]", ->
    nullRequester = (query, callback) ->
      callback(null, [])
      return

    nullDriver = druidDriver({
      requester: nullRequester
      dataSource: 'blah'
      approximate: true
    })

    emptyRequester = (query, callback) ->
      callback(null, [{result:[]}])
      return

    emptyDriver = druidDriver({
      requester: nullRequester
      dataSource: 'blah'
      approximate: true
    })

    describe "should return null correctly on an all query", ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

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
      query = new FacetQuery([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ])

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
    druidPass = druidRequester({
      host: '10.60.134.138'
      port: 8080
    })

    noFilter = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
    })

    filterSpec = {
      operation: 'filter'
      type: 'and'
      filters: [
        {
          type: 'within'
          attribute: 'time'
          range: [
            new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
            new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
          ]
        },
        {
          type: 'is'
          attribute: 'namespace'
          value: 'article'
        }
      ]
    }

    withFilter = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
      filter: FacetFilter.fromSpec(filterSpec)
    })

    it "should get back the same result", (done) ->
      noFilter {
        query: new FacetQuery([
          filterSpec
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


  describe "specific queries", ->
    druidPass = druidRequester({
      host: '10.60.134.138'
      port: 8080
    })

    driver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
    })

    it "should work with a null filter", (done) ->
      query = new FacetQuery([
        {
          operation: 'filter'
          type: 'and'
          filters: [
            {
              type: 'within'
              attribute: 'time'
              range: [
                new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0))
                new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))
              ]
            },
            {
              type: 'is'
              attribute: 'page'
              value: null
            }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])
      driver {query}, (err, res) ->
        expect(res).to.be.an('object') # to.deep.equal({})
        done()

    it "should get min/max time", (done) ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
      ])
      driver {query}, (err, res) ->
        expect(err).to.equal(null)
        expect(res).to.be.an('object')
        expect(res.prop.Min).to.be.an.instanceof(Date)
        expect(res.prop.Max).to.be.an.instanceof(Date)
        done()

    it "should complain if min/max time is mixed with other applies", (done) ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])
      driver {query}, (err, res) ->
        expect(err).to.not.equal(null)
        expect(err.message).to.equal("can not mix and match min / max time with other aggregates (for now)")
        done()
