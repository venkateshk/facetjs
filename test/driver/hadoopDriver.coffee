chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../build/query')

hadoopRequester = require('../../build/hadoopRequester')
hadoopDriver = require('../../build/hadoopDriver')

verbose = false

describe "Druid driver", ->
  @timeout(40 * 60 * 1000)

  describe "specific queries", ->
    hadoopPass = hadoopRequester({
      host: '10.151.42.82'
      port: '8080'
    })

    driver = hadoopDriver({
      requester: hadoopPass
      timeAttribute: 'timestamp'
      path: 's3://metamx-kafka-data/wikipedia-editstream/v4/beta'
      filters: null
    })

    # it "should work with a null filter", (done) ->
    #   query = new FacetQuery([
    #     {
    #       operation: 'filter'
    #       type: 'and'
    #       filters: [
    #         {
    #           type: 'within'
    #           attribute: 'time'
    #           range: [
    #             new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
    #             new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
    #           ]
    #         },
    #         {
    #           type: 'is'
    #           attribute: 'page'
    #           value: null
    #         }
    #       ]
    #     }
    #     { operation: 'apply', name: 'Count', aggregate: 'count' }
    #   ])
    #   driver {query}, (err, res) ->
    #     expect(res).to.be.an('object') # to.deep.equal({})
    #     done()

    # it "should get min/max time", (done) ->
    #   query = new FacetQuery([
    #     { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
    #     { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
    #   ])
    #   driver {query}, (err, res) ->
    #     expect(err).to.equal(null)
    #     expect(res).to.be.an('object')
    #     expect(res.prop.Min).to.be.an.instanceof(Date)
    #     expect(res.prop.Max).to.be.an.instanceof(Date)
    #     done()

    # it "should complain if min/max time is mixed with other applies", (done) ->
    #   query = new FacetQuery([
    #     { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
    #     { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
    #     { operation: 'apply', name: 'Count', aggregate: 'count' }
    #   ])
    #   driver {query}, (err, res) ->
    #     expect(err).to.not.equal(null)
    #     expect(err.message).to.equal("can not mix and match min / max time with other aggregates (for now)")
    #     done()

    # it "should work without a combine (single split)", (done) ->
    #   query = new FacetQuery([
    #     {
    #       operation: 'filter'
    #       type: 'within'
    #       attribute: 'time'
    #       range: [
    #         new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
    #         new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
    #       ]
    #     }
    #     { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
    #     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    #     { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    #   ])
    #   driver {query}, (err, res) ->
    #     expect(err).to.equal(null)
    #     expect(res).to.be.an('object')
    #     done()

    # it "should work without a combine (double split)", (done) ->
    #   query = new FacetQuery([
    #     {
    #       operation: 'filter'
    #       type: 'within'
    #       attribute: 'time'
    #       range: [
    #         new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
    #         new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
    #       ]
    #     }
    #     { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
    #     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    #     { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    #     { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

    #     { operation: 'split', name: 'Robot', bucket: 'identity', attribute: 'robot' }
    #     { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    #     { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
    #   ])
    #   driver {query}, (err, res) ->
    #     expect(err).to.equal(null)
    #     expect(res).to.be.an('object')
    #     done()

    it "should work with sort-by-delta on derived apply", (done) ->
      query = new FacetQuery([
        {
          operation: 'dataset'
          name: 'robots'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '1'
          }
        }
        {
          operation: 'dataset'
          name: 'humans'
          source: 'base'
          filter: {
            operation: 'filter'
            dataset: 'robots'
            type: 'is'
            attribute: 'robot'
            value: '0'
          }
        }
        {
          operation: 'filter'
          type: 'within'
          attribute: 'timestamp'
          range: [
            new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
            new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
          ]
        }
        {
          operation: 'split'
          name: 'Language'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'robots'
              bucket: 'identity'
              attribute: 'language'
            }
            {
              dataset: 'humans'
              bucket: 'identity'
              attribute: 'language'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'humans'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'robots'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'EditsDiff', compare: 'natural', direction: 'descending' }
          limit: 3
        }
      ])
      driver {query}, (err, res) ->
        console.log err
        expect(err).to.equal(null)
        expect(res).to.deep.equal({
          "prop": {},
          "splits": [
            {
              "prop": {
                "Language": "de",
                "EditsDiff": 7462.5
              }
            },
            {
              "prop": {
                "Language": "fr",
                "EditsDiff": 7246
              }
            },
            {
              "prop": {
                "Language": "es",
                "EditsDiff": 5212
              }
            }
          ]
        })
        done()
