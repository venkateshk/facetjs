chai = require("chai")
expect = chai.expect
utils = require('../utils')

druidRequester = require('../../../target/druidRequester')
druidDriver = require('../../../target/druidDriver')

verbose = false

describe "Druid driver tests", ->
  #@timeout(40 * 1000)

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
      callback(null, [])
      return

    emptyDriver = druidDriver({
      requester: nullRequester
      dataSource: 'blah'
      approximate: true
    })

    describe "should return null correctly on an all query", ->
      query = [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ]

      it "should work with [] return", (done) ->
        nullDriver query, (err, result) ->
          expect(result).to.deep.equal({})
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver query, (err, result) ->
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
        nullDriver query, (err, result) ->
          expect(result).to.deep.equal({})
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver query, (err, result) ->
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

      filter = {
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
        filter
      })

      it "should get back the same result", (done) ->
        noFilter [
          filter
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ], (err, noFilterRes) ->
          expect(noFilterRes).to.be.an('object')
          withFilter [
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ], (err, withFilterRes) ->
            expect(withFilterRes).to.be.an('object')
            expect(noFilterRes).to.deep.equal(withFilterRes)
            done()


    describe "should work with a null filter", ->
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

      filter = {
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

      it "should get back a result and not crash", (done) ->
        driver [
          filter
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ], (err, res) ->
          expect(res).to.be.an('object') # to.deep.equal({})
          done()
