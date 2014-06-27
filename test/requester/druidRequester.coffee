{ expect } = require("chai")

simpleLocator = require('../../src/locator/simpleLocator')
druidRequester = require('../../src/requester/druidRequester')

druidPass = druidRequester({
  locator: simpleLocator('10.136.50.119')
})

describe "Druid requester", ->
  @timeout(5 * 1000)

  describe "introspection", ->
    it "introspects single dataSource", (done) ->
      druidPass {
        query: {
          "queryType": "introspect",
          "dataSource": 'wikipedia_editstream'
        }
      }, (err, res) ->
        expect(err).to.not.exist
        expect(res.dimensions).be.an('Array')
        expect(res.metrics).be.an('Array')
        done()

    it "introspects multi dataSource", (done) ->
      druidPass {
        query: {
          "queryType": "introspect",
          "dataSource": {
            "type": "union"
            "dataSources": ['wikipedia_editstream', 'wikipedia_editstream']
          }
        }
      }, (err, res) ->
        expect(err).to.not.exist
        expect(res.dimensions).be.an('Array')
        expect(res.metrics).be.an('Array')
        done()

  describe "errors", ->
    it "correct error for bad datasource", (done) ->
      druidPass {
        query: {
          "queryType": "maxTime",
          "dataSource": 'wikipedia_editstream_borat'
        }
      }, (err, res) ->
        expect(err.message).to.equal("No such datasource")
        done()

    it "correct error for bad datasource (on introspect)", (done) ->
      druidPass {
        query: {
          "queryType": "introspect",
          "dataSource": 'wikipedia_editstream_borat'
        }
      }, (err, res) ->
        expect(err.message).to.equal("No such datasource")
        done()


  describe "basic working", ->
    it "gets max time", (done) ->
      druidPass {
        query: {
          "queryType": "maxTime",
          "dataSource": 'wikipedia_editstream'
        }
      }, (err, res) ->
        expect(err).to.not.exist
        expect(res.length).to.equal(1)
        expect(isNaN(new Date(res[0].result))).to.be.false
        done()

    it "works with regular time series", (done) ->
      druidPass {
        query: {
          "queryType": "timeseries",
          "dataSource": "wikipedia_editstream",
          "granularity": "hour",
          "aggregations": [
            { "type": "count", "name": "Count" }
          ],
          "intervals": [ "2014-01-01T00:00:00.000/2014-01-02T00:00:00.000" ]
        }
      }, (err, res) ->
        expect(err).to.not.exist
        expect(res.length).to.equal(24)
        done()

    it "works with regular time series in the far future", (done) ->
      druidPass {
        query: {
          "queryType": "timeseries",
          "dataSource": "wikipedia_editstream",
          "granularity": "hour",
          "aggregations": [
            { "type": "count", "name": "Count" }
          ],
          "intervals": [ "2045-01-01T00:00:00.000/2045-01-02T00:00:00.000" ]
        }
      }, (err, res) ->
        expect(err).to.not.exist
        expect(res.length).to.equal(0)
        done()

    it "works with regular time series in the far future with invalid data source", (done) ->
      druidPass {
        query: {
          "queryType": "timeseries",
          "dataSource": "wikipedia_editstream_borat",
          "granularity": "hour",
          "aggregations": [
            { "type": "count", "name": "Count" }
          ],
          "intervals": [ "2045-01-01T00:00:00.000/2045-01-02T00:00:00.000" ]
        }
      }, (err, res) ->
        expect(err.message).to.equal("No such datasource")
        done()


  describe "timeout", ->
    it "works in simple case", (done) ->
      timeoutDruidPass = druidRequester({
        locator: simpleLocator('10.69.20.5')
        timeout: 50
      })

      timeoutDruidPass {
        query: {
          "context": {
            #"timeout": 50
            "useCache": false
          }
          "queryType": "timeseries",
          "dataSource": "mmx_metrics",
          "granularity": "hour",
          "aggregations": [
            { "type": "count", "name": "Count" }
          ],
          "intervals": [ "2014-01-01T00:00:00.000/2014-01-02T00:00:00.000" ]
        }
      }, (err, res) ->
        expect(err?.message).to.equal("timeout")
        done()



