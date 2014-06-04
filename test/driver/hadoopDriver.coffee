chai = require("chai")
expect = chai.expect
utils = require('../utils')

{FacetQuery, FacetFilter} = require('../../src/query')

simpleLocator = require('../../src/locator/simpleLocator')

hadoopRequester = require('../../src/requester/hadoopRequester')
hadoopDriver = require('../../src/driver/hadoopDriver')

verbose = false

describe "Hadoop driver", ->
  @timeout(15 * 60 * 1000)

  describe "specific queries", ->
    hadoopPass = hadoopRequester({
      locator: simpleLocator('10.136.50.119')
    })

    driver = hadoopDriver({
      requester: hadoopPass
      timeAttribute: 'timestamp'
      path: 's3://metamx-kafka-data/wikipedia-editstream/v4/beta'
      filters: null
    })

    it.skip "should work with sort-by-delta on derived apply", (done) ->
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
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
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
        expect(err).to.not.exist
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
