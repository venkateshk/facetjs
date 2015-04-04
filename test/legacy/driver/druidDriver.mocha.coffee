{ expect } = require("chai")
utils = require('../../utils')

Q = require('q')
{ druidRequester } = require('facetjs-druid-requester')

facet = require('../../../build/facet')

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

{
  FacetQuery
  FacetFilter
  AttributeMeta
  FacetSplit
  FacetApply

  druidDriver
  DruidQueryBuilder
} = facet.legacy

info = require('../../info')

verbose = false

describe "Druid driver", ->
  @timeout(5 * 1000)

  describe "makes good queries", ->
    describe "good bucketing function (no before / no after)", ->
      queryBuilder = new DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromJS({
            type: 'range'
            separator: '|'
            rangeSize: 0.05
          })
        }
        forceInterval: false
        approximate: true
        context: {}
      })

      queryBuilder.addSplit(FacetSplit.fromJS({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      extractionFn = null

      it "has a extractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        extractionFnSrc = druidQuery.dimensions[0].extractionFn.function
        expect(extractionFnSrc).to.exist
        expect(->
          extractionFn = eval("(#{extractionFnSrc})")
        ).to.not.throw()
        expect(extractionFn).to.be.a('function')

      it "has a working extractionFn", ->
        expect(extractionFn("0.05|0.1")).to.equal("0000000000.05")
        expect(extractionFn("10.05|10.1")).to.equal("0000000010.05")
        expect(extractionFn("-10.1|-10.05")).to.equal("-0000000010.1")
        expect(extractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(extractionFn("50.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(extractionFn("50.05|50.09")).to.equal("null")

      it "is checks trailing zeroes", ->
        expect(extractionFn("50.05|50.10")).to.equal("null")

      it "is checks number of splits", ->
        expect(extractionFn("50.05|50.1|50.2")).to.equal("null")

      it "is checks separator", ->
        expect(extractionFn("50.05| 50.1")).to.equal("null")
        expect(extractionFn("50.05 |50.1")).to.equal("null")


    describe "good bucketing function (no before / 2 after)", ->
      queryBuilder = new DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromJS({
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

      queryBuilder.addSplit(FacetSplit.fromJS({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      extractionFn = null

      it "has a extractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        extractionFnSrc = druidQuery.dimensions[0].extractionFn.function
        expect(extractionFnSrc).to.exist
        expect(->
          extractionFn = eval("(#{extractionFnSrc})")
        ).to.not.throw()
        expect(extractionFn).to.be.a('function')

      it "has a working extractionFn", ->
        expect(extractionFn("0.05|0.10")).to.equal("0000000000.05")
        expect(extractionFn("10.05|10.10")).to.equal("0000000010.05")
        expect(extractionFn("-10.10|-10.05")).to.equal("-0000000010.1")
        expect(extractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(extractionFn("50.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(extractionFn("50.05|50.09")).to.equal("null")

      it "is checks trailing zeroes (none)", ->
        expect(extractionFn("50.05|50.1")).to.equal("null")

      it "is checks trailing zeroes (too many)", ->
        expect(extractionFn("50.050|50.100")).to.equal("null")

    describe "good bucketing function (4 before / no after)", ->
      queryBuilder = new DruidQueryBuilder({
        dataSource: 'some_data'
        timeAttribute: 'time'
        attributeMetas: {
          price_range: AttributeMeta.fromJS({
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

      queryBuilder.addSplit(FacetSplit.fromJS({
        name: 'PriceRange'
        bucket: 'identity'
        attribute: 'price_range'
      }))

      extractionFn = null

      it "has a extractionFn", ->
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.queryType).to.equal('groupBy')
        extractionFnSrc = druidQuery.dimensions[0].extractionFn.function
        expect(extractionFnSrc).to.exist
        expect(->
          extractionFn = eval("(#{extractionFnSrc})")
        ).to.not.throw()
        expect(extractionFn).to.be.a('function')

      it "has a working extractionFn", ->
        expect(extractionFn("0000.05|0000.1")).to.equal("0000000000.05")
        expect(extractionFn("0010.05|0010.1")).to.equal("0000000010.05")
        expect(extractionFn("-0010.1|-0010.05")).to.equal("-0000000010.1")
        expect(extractionFn("blah_unknown")).to.equal("null")

      it "is checks end", ->
        expect(extractionFn("0050.05|whatever")).to.equal("null")

      it "is checks range size", ->
        expect(extractionFn("0050.05|0050.09")).to.equal("null")

      it "is checks number of digits (too few)", ->
        expect(extractionFn("050.05|050.1")).to.equal("null")

      it "is checks number of digits (too many)", ->
        expect(extractionFn("00050.05|00050.1")).to.equal("null")

    describe "good native filtered aggregator", ->
      queryBuilder = null
      beforeEach ->
        queryBuilder = new DruidQueryBuilder({
          dataSource: 'some_data'
          timeAttribute: 'time'
          attributeMetas: {}
          forceInterval: false
          approximate: true
          context: {}
        })

      it "makes the correct aggregate for is filters", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'HondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: { type: 'is', attribute: 'make', value: 'honda' }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "name": "HondaPrice"
            "type": "filtered"
            "aggregator": {
              "name": "HondaPrice"
              "fieldName": "price"
              "type": "doubleSum"
            }
            "filter": {
              "dimension": "make"
              "type": "selector"
              "value": "honda"
            }
          }
        ])

      it "makes the correct aggregate for in filters with single value", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'HondaPrice2'
            aggregate: 'sum'
            attribute: 'price'
            filter: { type: 'in', attribute: 'make', values: ['honda'] }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "name": "HondaPrice2"
            "type": "filtered"
            "aggregator": {
              "name": "HondaPrice2"
              "fieldName": "price"
              "type": "doubleSum"
            }
            "filter": {
              "dimension": "make"
              "type": "selector"
              "value": "honda"
            }
          }
        ])


      it "makes the correct aggregate for in filters with multiple values", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'InHondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: { type: 'in', attribute: 'make', values: ['honda', 'hyundai'] }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "name": "InHondaPrice"
            "type": "filtered"
            "aggregator": {
              "name": "InHondaPrice"
              "fieldName": "price"
              "type": "doubleSum"
            }
            "filter": {
              "type": "or",
              "fields": [
                {
                  "type": "selector",
                  "dimension": "make",
                  "value": "honda"
                },
                {
                  "type": "selector",
                  "dimension": "make",
                  "value": "hyundai"
                }
              ]
            }
          }
        ])

      it "makes the correct native aggregate for not filters only with is", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'NotHondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: {
              type: 'not'
              filter: {type: 'is', attribute: 'make', value: 'honda' }
            }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "name": "NotHondaPrice"
            "type": "filtered"
            "aggregator": {
              "name": "NotHondaPrice"
              "fieldName": "price"
              "type": "doubleSum"
            }
            "filter": {
              "type": "not"
              "field": {
                "dimension": "make"
                "type": "selector"
                "value": "honda"
              }
            }
          }
        ])


      it "makes the correct native aggregate for or filters only with is", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'OrHondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: {
              type: 'or'
              filters: [
                {type: 'is', attribute: 'make', value: 'honda' }
                {type: 'is', attribute: 'year', value: '2014' }
              ]
            }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "type": "filtered",
            "name": "OrHondaPrice",
            "filter": {
              "type": "or",
              "fields": [
                {
                  "type": "selector",
                  "dimension": "make",
                  "value": "honda"
                },
                {
                  "type": "selector",
                  "dimension": "year",
                  "value": "2014"
                }
              ]
            },
            "aggregator": {
              "name": "OrHondaPrice",
              "type": "doubleSum",
              "fieldName": "price"
            }
          }
        ])

      it "makes the correct native aggregate for and filters only with is", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'AndHondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: {
              type: 'and'
              filters: [
                {type: 'is', attribute: 'make', value: 'honda' }
                {type: 'is', attribute: 'year', value: '2014' }
              ]
            }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "type": "filtered",
            "name": "AndHondaPrice",
            "filter": {
              "type": "and",
              "fields": [
                {
                  "type": "selector",
                  "dimension": "make",
                  "value": "honda"
                },
                {
                  "type": "selector",
                  "dimension": "year",
                  "value": "2014"
                }
              ]
            },
            "aggregator": {
              "name": "AndHondaPrice",
              "type": "doubleSum",
              "fieldName": "price"
            }
          }
        ])

      it "makes the correct native aggregate for complex filters only with is", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'ComplexHondaPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: {
              type: 'and'
              filters: [
                {type: 'is', attribute: 'make', value: 'honda' }
                {
                  type: 'not'
                  filter: {type: 'is', attribute: 'year', value: '2014' }
                }
              ]
            }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "type": "filtered",
            "name": "ComplexHondaPrice",
            "filter": {
              "type": "and",
              "fields": [
                {
                  "type": "selector",
                  "dimension": "make",
                  "value": "honda"
                },
                {
                  "type": "not",
                  "field": {
                    "type": "selector",
                    "dimension": "year",
                    "value": "2014"
                  }
                }
              ]
            },
            "aggregator": {
              "name": "ComplexHondaPrice",
              "type": "doubleSum",
              "fieldName": "price"
            }
          }
        ])

      it "does not make a native aggregate for other filters", ->
        queryBuilder.addApplies([
          FacetApply.fromJS({
            name: 'HondaAndLexusPrice'
            aggregate: 'sum'
            attribute: 'price'
            filter: {
              type: 'contains'
              attribute: 'make'
              value: 'honda'
            }
          })
        ])
        druidQuery = queryBuilder.getQuery()
        expect(druidQuery.aggregations).to.deep.equal([
          {
            "fieldNames": [
              "make"
              "price"
            ]
            "fnAggregate": "function(cur,v0,a){return cur + (String(v0).indexOf(\'honda\') !== -1?a:0);}"
            "fnCombine": "function(pa,pb){return pa + pb;}"
            "fnReset": "function(){return 0;}"
            "name": "HondaAndLexusPrice"
            "type": "javascript"
          }
        ])

  describe "introspects", ->
    druidPass = druidRequester({
      host: info.druidHost
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
    })

    it "works", (testComplete) ->
      wikiDriver.introspect(null).then((attributes) ->
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
            "name": "newPage"
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
          }
        ])
        testComplete()
      ).done()

  describe "should work when getting back [] and [{result:[]}]", ->
    nullDriver = druidDriver({
      requester: (query) -> Q([])
      dataSource: 'blah'
      approximate: true
    })

    emptyDriver = druidDriver({
      requester: (query) -> Q([{result:[]}])
      dataSource: 'blah'
      approximate: true
    })

    describe "should return null correctly on an all query", ->
      query = FacetQuery.fromJS([
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      it "should work with [] return", (testComplete) ->
        nullDriver({query}).then((result) ->
          expect(result.toJS()).to.deep.equal({
            prop: {
              Count: 0
            }
          })
          testComplete()
        ).done()

      it "should work with [{result:[]}] return", (testComplete) ->
        emptyDriver({query}).then((result) ->
          expect(result.toJS()).to.deep.equal({
            prop: {
              Count: 0
            }
          })
          testComplete()
        ).done()

    describe "should return null correctly on a topN query", ->
      query = FacetQuery.fromJS([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'ascending' } }
      ])

      it "should work with [] return", (testComplete) ->
        nullDriver({query}).then((result) ->
          expect(result.toJS()).to.deep.equal({})
          testComplete()
        ).done()

      it "should work with [{result:[]}] return", (testComplete) ->
        emptyDriver({query}).then((result) ->
          expect(result.toJS()).to.deep.equal({})
          testComplete()
        ).done()

  describe "should work when getting back crap data", ->
    crapDriver = druidDriver({
      requester: (query) -> Q("[Does this look like data to you?")
      dataSource: 'blah'
      approximate: true
    })

    it "should work with all query", (testComplete) ->
      query = FacetQuery.fromJS([
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      crapDriver({query})
      .then(-> throw new Error('DID_NOT_ERROR'))
      .fail((err) ->
        expect(err.message).to.equal('unexpected result from Druid (all)')
        testComplete()
      ).done()

    it "should work with timeseries query", (testComplete) ->
      query = FacetQuery.fromJS([
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'timestamp', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ])

      crapDriver({query})
      .then(-> throw new Error('DID_NOT_ERROR'))
      .fail((err) ->
        expect(err.message).to.equal('unexpected result from Druid (timeseries)')
        testComplete()
      ).done()

  describe "should work with driver level filter", ->
    druidPass = druidRequester({
      host: info.druidHost
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
      filter: FacetFilter.fromJS(filterSpec)
    })

    it "should get back the same result", (testComplete) ->
      noFilterRes = null
      noFilter({
        query: FacetQuery.fromJS([
          filterSpec
          { operation: 'apply', name: 'Count', aggregate: 'count' }
        ])
      }).then((_noFilterRes) ->
        noFilterRes = _noFilterRes
        return withFilter {
          query: FacetQuery.fromJS([
            { operation: 'apply', name: 'Count', aggregate: 'count' }
          ])
        }
      ).then((withFilterRes) ->
        expect(noFilterRes.valueOf()).to.deep.equal(withFilterRes.valueOf())
        testComplete()
      ).done()

  describe "should work with nothingness", ->
    druidPass = druidRequester({
      host: info.druidHost
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
    })

    it "does handles nothingness", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
      ]
      wikiDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          "prop": {}
        })
        testComplete()
      ).done()

    it "deals well with empty results", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
      wikiDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        testComplete()
      ).done()

    it "deals well with empty results and split", (testComplete) ->
      querySpec = [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }

        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
      wikiDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {
            Count: 0
          }
          splits: []
        })
        testComplete()
      ).done()

  describe "should work with inferred nothingness", ->
    druidPass = druidRequester({
      host: info.druidHost
    })

    wikiDriver = druidDriver({
      requester: druidPass
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      forceInterval: true
      filter: FacetFilter.fromJS({
        type: 'within'
        attribute: 'time'
        range: [
          new Date("2013-02-26T00:00:00Z")
          new Date("2013-02-27T00:00:00Z")
        ]
      })
    })

    it "deals well with empty results", (testComplete) ->
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
      wikiDriver({ query: FacetQuery.fromJS(querySpec) }).then((result) ->
        expect(result.toJS()).to.deep.equal({
          prop: {
            Count: 0
          }
        })
        testComplete()
      ).done()

  describe "specific queries", ->
    druidPass = druidRequester({
      host: info.druidHost
    })
    driver = null

    beforeEach ->
      driver = druidDriver({
        requester: druidPass
        dataSource: 'wikipedia_editstream'
        timeAttribute: 'time'
        approximate: true
        forceInterval: true
      })

    it "should work with a null filter", (testComplete) ->
      query = FacetQuery.fromJS([
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
      driver({query}).then((result) ->
        expect(result).to.be.an('object') # to.deep.equal({})
        testComplete()
      ).done()

    it "should get min/max time", (testComplete) ->
      query = FacetQuery.fromJS([
        {
          operation: "filter"
          type: "within"
          attribute: "timestamp"
          range: [new Date("2010-01-01T00:00:00"), new Date("2045-01-01T00:00:00")]
        }
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
      ])
      driver({query}).then((result) ->
        expect(result.prop.Min).to.be.an.instanceof(Date)
        expect(result.prop.Max).to.be.an.instanceof(Date)
        testComplete()
      ).done()

    describe 'with dataSourceMetaData', ->
      beforeEach ->
        driver = druidDriver({
          requester: druidPass
          dataSource: 'wikipedia_editstream'
          timeAttribute: 'time'
          approximate: true
          useDataSourceMetadata: true
          forceInterval: true
        })

      it "should get max time only", (testComplete) ->
        query = FacetQuery.fromJS([
          {
            operation: "filter"
            type: "within"
            attribute: "timestamp"
            range: [new Date("2010-01-01T00:00:00"), new Date("2045-01-01T00:00:00")]
          }
          { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
        ])
        driver({query}).then((result) ->
          expect(result.prop.Max).to.be.an.instanceof(Date)
          expect(isNaN(result.prop.Max.getTime())).to.be.false
          testComplete()
        ).done()

    describe 'with vanilla', ->
      it "should get max time only", (testComplete) ->
        query = FacetQuery.fromJS([
          {
            operation: "filter"
            type: "within"
            attribute: "timestamp"
            range: [new Date("2010-01-01T00:00:00"), new Date("2045-01-01T00:00:00")]
          }
          { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
        ])
        driver({query}).then((result) ->
          expect(result.prop.Max).to.be.an.instanceof(Date)
          expect(isNaN(result.prop.Max.getTime())).to.be.false
          testComplete()
        ).done()

    it "should complain if min/max time is mixed with other applies", (testComplete) ->
      query = FacetQuery.fromJS([
        { operation: 'apply', name: 'Min', aggregate: 'min', attribute: 'time' }
        { operation: 'apply', name: 'Max', aggregate: 'max', attribute: 'time' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ])
      driver({query})
      .then(-> throw new Error('DID_NOT_ERROR'))
      .fail((err) ->
        expect(err.message).to.equal("can not mix and match min / max time with other aggregates (for now)")
        testComplete()
      ).done()

    it "should deal with average aggregate", (testComplete) ->
      query = FacetQuery.fromJS([
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
      driver({query}).then((result) ->
        expect(result.toJS()).to.be.deep.equal({
          prop: {
            "AvgAdded": 216.43371007799223
            "AvgDelta/100": 0.31691260511524555
          }
        })
        testComplete()
      ).done()

    it.skip "should deal with arbitrary context", (testComplete) ->
      query = FacetQuery.fromJS([
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
      driver({context, query}).then((result) ->
        expect(result.toJS()).to.be.deep.equal({
          prop: {
            "AvgAdded": 216.43371007799223
          }
        })
        testComplete()
      ).done()

    it "should work without a combine (single split)", (testComplete) ->
      query = FacetQuery.fromJS([
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
      driver({query}).then((result) ->
        expect(result).to.be.an('object')
        testComplete()
      ).done()

    it "should work without a combine (double split)", (testComplete) ->
      query = FacetQuery.fromJS([
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
      driver({query}).then((result) ->
        expect(result).to.be.an('object')
        testComplete()
      ).done()

    it "should work with sort-by-delta on derived apply", (testComplete) ->
      query = FacetQuery.fromJS([
        {
          operation: 'dataset'
          name: 'robots'
          source: 'base'
          filter: {
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
      driver({query}).then((result) ->
        expect(result.toJS()).to.deep.equal({
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
        testComplete()
      ).done()

    it "should work with sort-by-delta on a timePeriod split", (testComplete) ->
      query = FacetQuery.fromJS([
        {
          operation: 'dataset'
          name: 'prevDate'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T00:00:00Z")
              new Date("2013-02-26T03:00:00Z")
            ]
          }
        }
        {
          operation: 'dataset'
          name: 'currentData'
          source: 'base'
          filter: {
            operation: 'filter'
            type: 'within'
            attribute: 'time'
            range: [
              new Date("2013-02-26T21:00:00Z")
              new Date("2013-02-27T00:00:00Z")
            ]
          }
        }
        {
          operation: 'split'
          name: 'TimeByHour'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'prevDate'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
              warp: 'PT21H'
            }
            {
              dataset: 'currentData'
              bucket: 'timePeriod'
              attribute: 'time'
              timezone: 'Etc/UTC'
              period: 'PT1H'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'EditsDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'currentData'
              arithmetic: 'divide'
              operands: [
                { aggregate: 'sum', attribute: 'count' }
                { aggregate: 'constant', value: 2 }
              ]
            }
            {
              dataset: 'prevDate'
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
          sort: { prop: 'TimeByHour', compare: 'natural', direction: 'ascending' }
        }
      ])
      driver({query}).then((result) ->
        expect(result.toJS()).to.deep.equal({
          "prop": {},
          "splits": [
            {
              "prop": {
                "EditsDiff": -551
                "TimeByHour": [
                  new Date("2013-02-26T21:00:00Z")
                  new Date("2013-02-26T22:00:00Z")
                ]
              }
            }
            {
              "prop": {
                "EditsDiff": -5238
                "TimeByHour": [
                  new Date("2013-02-26T22:00:00Z")
                  new Date("2013-02-26T23:00:00Z")
                ]
              }
            }
            {
              "prop": {
                "EditsDiff": 677
                "TimeByHour": [
                  new Date("2013-02-26T23:00:00Z")
                  new Date("2013-02-27T00:00:00Z")
                ]
              }
            }
          ]
        })
        testComplete()
      ).done()


  describe "propagates context", ->
    querySpy = null
    requesterSpy = (request) ->
      querySpy(request.query)
      return Q([])

    driver = druidDriver({
      requester: requesterSpy
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
    })

    it "does not send empty context", (testComplete) ->
      context = {}
      query = FacetQuery.fromJS([
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

      driver({
        context
        query
      }).then((result) ->
        expect(count).to.equal(1)
        testComplete()
      ).done()

    it "propagates existing context", (testComplete) ->
      context = {
        userData: {
          a: 1
          b: 2
        }
        priority: 5
      }
      query = FacetQuery.fromJS([
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

      driver({
        context
        query
      }).then((result) ->
        expect(count).to.equal(1)
        testComplete()
      ).done()

  describe "acknowledges attribute metas", ->
    querySpy = null
    requesterSpy = (request) ->
      querySpy(request.query)
      return Q([])

    driver = druidDriver({
      requester: requesterSpy
      dataSource: 'wikipedia_editstream'
      timeAttribute: 'time'
      approximate: true
      attributeMetas: {
        page: AttributeMeta.fromJS({
          type: 'large'
        })
      }
    })

    it "does not send empty context", (testComplete) ->
      context = {}
      query = FacetQuery.fromJS([
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      ])

      count = 0
      querySpy = (query) ->
        count++
        expect(query.context['doAggregateTopNMetricFirst']).to.be.true
        return

      driver({
        context
        query
      }).then((result) ->
        expect(count).to.equal(1)
        testComplete()
      ).done()
