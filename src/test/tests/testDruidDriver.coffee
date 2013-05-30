chai = require("chai")
expect = chai.expect
utils = require('../utils')

druidRequester = require('../../../target/druidRequester')
druidDriver = require('../../../target/druidDriver')

verbose = false

describe "Druid driver tests", ->
  #@timeout(40 * 1000)

  describe "Druid should work when getting back [] and [{result:[]}]", ->
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

