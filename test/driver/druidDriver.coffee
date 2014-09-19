chai = require("chai")
expect = chai.expect
utils = require('../utils')

{
  FacetQuery
  FacetFilter
  AttributeMeta
  FacetSplit
} = require('../../src/query')

simpleLocator = require('../../src/locator/simpleLocator')

druidRequester = require('../../src/requester/druidRequester')
druidDriver = require('../../src/driver/druidDriver')

verbose = false

describe "Druid driver", ->
  @timeout(5 * 1000)

  describe "makes good queries", ->
    describe "good bucketing function (no before / no after)", ->
      queryBuilder = new druidDriver.DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromSpec({
            type: 'range'
            separator: '|'
            rangeSize: 0.05
          })
        }
        forceInterval: false
        approximate: true
        context: {}
      })

      queryBuilder.addSplit(FacetSplit.fromSpec({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      dimExtractionFn = null

      it "has a dimExtractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        dimExtractionFnSrc = druidQuery.dimensions[0].dimExtractionFn.function
        expect(dimExtractionFnSrc).to.exist
        expect(->
          dimExtractionFn = eval("(#{dimExtractionFnSrc})")
        ).to.not.throw()
        expect(dimExtractionFn).to.be.a('function')

      it "has a working dimExtractionFn", ->
        expect(dimExtractionFn("0.05|0.1")).to.equal("0000000000.05")
        expect(dimExtractionFn("10.05|10.1")).to.equal("0000000010.05")
        expect(dimExtractionFn("-10.1|-10.05")).to.equal("-0000000010.1")
        expect(dimExtractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(dimExtractionFn("50.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(dimExtractionFn("50.05|50.09")).to.equal("null")

      it "is checks trailing zeroes", ->
        expect(dimExtractionFn("50.05|50.10")).to.equal("null")

      it "is checks number of splits", ->
        expect(dimExtractionFn("50.05|50.1|50.2")).to.equal("null")

      it "is checks separator", ->
        expect(dimExtractionFn("50.05| 50.1")).to.equal("null")
        expect(dimExtractionFn("50.05 |50.1")).to.equal("null")


    describe "good bucketing function (no before / 2 after)", ->
      queryBuilder = new druidDriver.DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromSpec({
            type: 'range'
            separator: '|'
            rangeSize: 0.05
            digitsAfterDecimal: 2
          })
        }
        forceInterval: false
        approximate: true
        context: {}
      })

      queryBuilder.addSplit(FacetSplit.fromSpec({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      dimExtractionFn = null

      it "has a dimExtractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        dimExtractionFnSrc = druidQuery.dimensions[0].dimExtractionFn.function
        expect(dimExtractionFnSrc).to.exist
        expect(->
          dimExtractionFn = eval("(#{dimExtractionFnSrc})")
        ).to.not.throw()
        expect(dimExtractionFn).to.be.a('function')

      it "has a working dimExtractionFn", ->
        expect(dimExtractionFn("0.05|0.10")).to.equal("0000000000.05")
        expect(dimExtractionFn("10.05|10.10")).to.equal("0000000010.05")
        expect(dimExtractionFn("-10.10|-10.05")).to.equal("-0000000010.1")
        expect(dimExtractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(dimExtractionFn("50.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(dimExtractionFn("50.05|50.09")).to.equal("null")

      it "is checks trailing zeroes (none)", ->
        expect(dimExtractionFn("50.05|50.1")).to.equal("null")

      it "is checks trailing zeroes (too many)", ->
        expect(dimExtractionFn("50.050|50.100")).to.equal("null")

    describe "good bucketing function (4 before / no after)", ->
      queryBuilder = new druidDriver.DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromSpec({
            type: 'range'
            separator: '|'
            rangeSize: 0.05
            digitsBeforeDecimal: 4
          })
        }
        forceInterval: false
        approximate: true
        context: {}
      })

      queryBuilder.addSplit(FacetSplit.fromSpec({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      dimExtractionFn = null

      it "has a dimExtractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        dimExtractionFnSrc = druidQuery.dimensions[0].dimExtractionFn.function
        expect(dimExtractionFnSrc).to.exist
        expect(->
          dimExtractionFn = eval("(#{dimExtractionFnSrc})")
        ).to.not.throw()
        expect(dimExtractionFn).to.be.a('function')

      it "has a working dimExtractionFn", ->
        expect(dimExtractionFn("0000.05|0000.1")).to.equal("0000000000.05")
        expect(dimExtractionFn("0010.05|0010.1")).to.equal("0000000010.05")
        expect(dimExtractionFn("-0010.1|-0010.05")).to.equal("-0000000010.1")
        expect(dimExtractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(dimExtractionFn("0050.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(dimExtractionFn("0050.05|0050.09")).to.equal("null")

      it "is checks number of digits (too few)", ->
        expect(dimExtractionFn("050.05|050.1")).to.equal("null")

      it "is checks number of digits (too many)", ->
        expect(dimExtractionFn("00050.05|00050.1")).to.equal("null")


  describe "introspects", ->
    druidPass = druidRequester({
      locator: simpleLocator('10.169.43.71')
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
    })

    it "works", (done) ->
      wikiDriver.introspect null, (err, attributes) ->
        expect(err).to.not.exist
        expect(attributes).to.deep.equal([
          {
            "name": "time",
            "time": true
          },
          {
            "name": "anonymous",
            "categorical": true
          },
          {
            "name": "area_code",
            "categorical": true
          },
          {
            "name": "city",
            "categorical": true
          },
          {
            "name": "continent_code",
            "categorical": true
          },
          {
            "name": "country_name",
            "categorical": true
          },
          {
            "name": "dma_code",
            "categorical": true
          },
          {
            "name": "geo",
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
            "name": "network",
            "categorical": true
          },
          {
            "name": "newpage",
            "categorical": true
          },
          {
            "name": "page",
            "categorical": true
          },
          {
            "name": "postal_code",
            "categorical": true
          },
          {
            "name": "region_lookup",
            "categorical": true
          },
          {
            "name": "robot",
            "categorical": true
          },
          {
            "name": "unpatrolled",
            "categorical": true
          },
          {
            "name": "user",
            "categorical": true
          },
          {
            "name": "added",
            "numeric": true
          },
          {
            "name": "count",
            "numeric": true
          },
          {
            "name": "deleted",
            "numeric": true
          },
          {
            "name": "delta",
            "numeric": true
          },
          {
            "name": "variation",
            "numeric": true
          }
        ])
        done()
        return

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
          expect(result.valueOf()).to.deep.equal({
            prop: {
              Count: 0
            }
          })
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result.valueOf()).to.deep.equal({
            prop: {
              Count: 0
            }
          })
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
          expect(result.valueOf()).to.deep.equal({})
          done()
          return

      it "should work with [{result:[]}] return", (done) ->
        emptyDriver {query}, (err, result) ->
          expect(err).to.be.null
          expect(result.valueOf()).to.deep.equal({})
          done()

  describe "should work with driver level filter", ->
    druidPass = druidRequester({
      locator: simpleLocator('10.169.43.71')
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
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
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
        expect(err).to.be.null
        withFilter {
          query: new FacetQuery([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        }, (err, withFilterRes) ->
          expect(noFilterRes.valueOf()).to.deep.equal(withFilterRes.valueOf())
          done()

  describe "should work with nothingness", ->
    druidPass = druidRequester({
      locator: simpleLocator('10.169.43.71')
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
    })

    it "does handles nothingness", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
      ]
      wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.not.exist
        expect(result.valueOf()).to.deep.equal({
          "prop": {}
        })
        done()

    it "deals well with empty results", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        done()

    it "deals well with empty results and split", (done) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }

        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
      wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({
          prop: {
            Count: 0
          }
          splits: []
        })
        done()

  describe "should work with inferred nothingness", ->
    druidPass = druidRequester({
      locator: simpleLocator('10.169.43.71')
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
      filter: FacetFilter.fromSpec({
        type: 'within'
        attribute: 'time'
        range: [
          new Date("2013-02-26T00:00:00Z")
          new Date("2013-02-27T00:00:00Z")
        ]
      })
    })

    it "deals well with empty results", (done) ->
      querySpec = [
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-28T00:00:00Z")
            new Date("2013-02-29T00:00:00Z")
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      wikiDriver { query: new FacetQuery(querySpec) }, (err, result) ->
        expect(err).to.be.null
        expect(result.valueOf()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        done()

  describe "specific queries", ->
    druidPass = druidRequester({
      locator: simpleLocator('10.169.43.71')
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
                new Date("2013-02-26T00:00:00Z")
                new Date("2013-02-27T00:00:00Z")
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
      driver {query}, (err, result) ->
        expect(result).to.be.an('object') # to.deep.equal({})
        done()

    it "should get min/max time", (done) ->
      query = new FacetQuery([
        {
          operation: "filter"
          type: "within"
          attribute: "timestamp"
          range: [new Date("2010-01-01T00:00:00"), new Date("2045-01-01T00:00:00")]
        }
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result.prop.Min).to.be.an.instanceof(Date)
        expect(result.prop.Max).to.be.an.instanceof(Date)
        done()

    it "should get max time only", (done) ->
      query = new FacetQuery([
        {
          operation: "filter"
          type: "within"
          attribute: "timestamp"
          range: [new Date("2010-01-01T00:00:00"), new Date("2045-01-01T00:00:00")]
        }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result.prop.Max).to.be.an.instanceof(Date)
        expect(isNaN(result.prop.Max.getTime())).to.be.false
        done()

    it "should complain if min/max time is mixed with other applies", (done) ->
      query = new FacetQuery([
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.equal(null)
        expect(err.message).to.equal("can not mix and match min / max time with other aggregates (for now)")
        done()

    it "should deal with average aggregate", (done) ->
      query = new FacetQuery([
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
          ]
        }
        { operation: 'apply', name: 'AvgAdded', aggregate: 'average', attribute: 'added' }
        {
          operation: 'apply'
          name: 'AvgDelta/100'
          arithmetic: "divide"
          operands: [
            { aggregate: "average", attribute: "delta" }
            { aggregate: "constant", value: 100 }
          ]
        }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result.valueOf()).to.be.deep.equal({
          prop: {
            "AvgAdded": 216.43371007799223
            "AvgDelta/100": 0.31691260511524555
          }
        })
        done()

    it.skip "should deal with arbitrary context", (done) ->
      query = new FacetQuery([
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
          ]
        }
        { operation: 'apply', name: 'AvgAdded', aggregate: 'average', attribute: 'added' }
      ])
      context = {
        userData: { hello: "world" }
        youngIsCool: true
      }
      driver {context, query}, (err, result) ->
        expect(err).to.not.exist
        expect(result.valueOf()).to.be.deep.equal({
          prop: {
            "AvgAdded": 216.43371007799223
          }
        })
        done()

    it "should work without a combine (single split)", (done) ->
      query = new FacetQuery([
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
          ]
        }
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result).to.be.an('object')
        done()

    it "should work without a combine (double split)", (done) ->
      query = new FacetQuery([
        {
          operation: 'filter'
          type: 'within'
          attribute: 'time'
          range: [
            new Date("2013-02-26T00:00:00Z")
            new Date("2013-02-27T00:00:00Z")
          ]
        }
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        { operation: 'split', name: 'Robot', bucket: 'identity', attribute: 'robot' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ])
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result).to.be.an('object')
        done()

    it "should work with numeric IS filters"

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
          attribute: 'time'
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
      driver {query}, (err, result) ->
        expect(err).to.not.exist
        expect(result.valueOf()).to.deep.equal({
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


  describe "propagates context", ->
    querySpy = null
    requesterSpy = (request, callback) ->
      querySpy(request.query)
      callback(null, [])
      return

    driver = druidDriver({
      requester: requesterSpy
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
    })

    it "does not send empty context", (done) ->
      context = {}
      query = new FacetQuery([
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])

      count = 0
      querySpy = (query) ->
        count++
        expect(query).to.deep.equal({
          "queryType": "timeseries",
          "dataSource": "wikipedia_editstream",
          "granularity": "all",
          "intervals": [
            "1000-01-01/3000-01-01"
          ],
          "aggregations": [
            { "name": "Count", "type": "count" }
          ]
        })
        return

      driver {
        context
        query
      }, (err, result) ->
        expect(count).to.equal(1)
        done()

    it "propagates existing context", (done) ->
      context = {
        userData: {
          a: 1
          b: 2
        }
        priority: 5
      }
      query = new FacetQuery([
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])

      count = 0
      querySpy = (query) ->
        count++
        expect(query).to.deep.equal({
          "queryType": "timeseries",
          "dataSource": "wikipedia_editstream",
          "granularity": "all",
          "intervals": [
            "1000-01-01/3000-01-01"
          ],
          "context": {
            "userData": {
              "a": 1,
              "b": 2
            },
            "priority": 5
          },
          "aggregations": [
            { "name": "Count", "type": "count" }
          ]
        })
        return

      driver {
        context
        query
      }, (err, result) ->
        expect(count).to.equal(1)
        done()

  describe "acknowledges attribute metas", ->
    querySpy = null
    requesterSpy = (request, callback) ->
      querySpy(request.query)
      callback(null, [])
      return

    driver = druidDriver({
      requester: requesterSpy
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      attributeMetas: {
        page: AttributeMeta.fromSpec({
          type: 'large'
        })
      }
    })

    it "does not send empty context", (done) ->
      context = {}
      query = new FacetQuery([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      count = 0
      querySpy = (query) ->
        count++
        expect(query.context['doAggregateTopNMetricFirst']).to.be.true
        return

      driver {
        context
        query
      }, (err, result) ->
        expect(count).to.equal(1)
        done()

