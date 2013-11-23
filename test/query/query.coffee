chai = require("chai")
expect = chai.expect

{FacetQuery} = require('../../build/query')

describe "FacetQuery", ->

  describe "errors", ->
    it "throws bad command", ->
      querySpec = [
        'blah'
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "unrecognizable command")

    it "throws if no operation in command", ->
      querySpec = [
        {}
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "operation not defined")

    it "throws invalid operation in command", ->
      querySpec = [
        { operation: ['wtf?'] }
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "invalid operation")

    it "throws unknown operation in command", ->
      querySpec = [
        { operation: 'poo' }
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "unknown operation 'poo'")

    it "throws split-less combine", ->
      querySpec = [
        {
          operation: 'combine'
          method: 'slice'
          sort: { compare: 'natural', prop: 'Count', direction: 'descending'  }
        }
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "combine called without split")

    it "throws if sorting on unknown prop", ->
      querySpec = [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'WTF', direction: 'descending' }, limit: 5 }
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "sort on unknown prop 'WTF'")

    it "throws if sorting on unknown prop in second split", ->
      querySpec = [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
      expect(-> new FacetQuery(querySpec)).to.throw(Error, "sort on unknown prop 'Count'")


  describe "preserves", ->
    it "empty", ->
      querySpec = []
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "simple", ->
      querySpec = [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "simple with filter", ->
      querySpec = [
        { operation: 'filter', attribute: 'language', type: 'is', value: 'en' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "simple with arithmetic applies", ->
      querySpec = [
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        {
          operation: 'apply'
          name: 'Added + Deleted'
          arithmetic: 'add'
          operands: [
            { aggregate: 'sum', attribute: 'added' }
            { aggregate: 'sum', attribute: 'deleted' }
          ]
        }
        {
          operation: 'apply'
          name: 'Added - Deleted'
          arithmetic: 'subtract'
          operands: [
            { aggregate: 'sum', attribute: 'added' }
            { aggregate: 'sum', attribute: 'deleted' }
          ]
        }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "split combine", ->
      querySpec = [
        { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "split apply combine", ->
      querySpec = [
        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 5 }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "split apply combine ^2", ->
      querySpec = [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        { operation: 'split', name: 'Page', bucket: 'identity', attribute: 'page' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "split apply combine + segment filter", ->
      querySpec = [
        { operation: 'split', name: 'Language', bucket: 'identity', attribute: 'language' }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }

        {
          operation: 'split'
          name: 'Page', bucket: 'identity', attribute: 'page'
          segmentFilter: {
            type: 'in'
            prop: 'Language'
            values: ['en', 'sv']
          }
        }
        { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
        { operation: 'apply', name: 'Added', aggregate: 'sum', attribute: 'added' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 3 }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "multi-dataset query", ->
      querySpec = [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'dataset'
          name: 'good-cut'
          source: 'base'
          filter: {
            dataset: 'good-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Good'
          }
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'ideal-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
            {
              dataset: 'good-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
          limit: 4
        }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "multi-dataset query (computability)", ->
      querySpec = [
        {
          operation: 'dataset'
          datasets: ['ideal-cut', 'good-cut']
        }
        {
          operation: 'filter'
          dataset: 'ideal-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Ideal'
        }
        {
          operation: 'filter'
          dataset: 'good-cut'
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'ideal-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
            {
              dataset: 'good-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
          limit: 4
        }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal [
        {
          operation: 'dataset'
          name: 'ideal-cut'
          source: 'base'
          filter: {
            dataset: 'ideal-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Ideal'
          }
        }
        {
          operation: 'dataset'
          name: 'good-cut'
          source: 'base'
          filter: {
            dataset: 'good-cut'
            type: 'is'
            attribute: 'cut'
            value: 'Good'
          }
        }
        {
          operation: 'split'
          name: 'Clarity'
          bucket: 'parallel'
          splits: [
            {
              dataset: 'ideal-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
            {
              dataset: 'good-cut'
              bucket: 'identity'
              attribute: 'clarity'
            }
          ]
        }
        {
          operation: 'apply'
          name: 'PriceDiff'
          arithmetic: 'subtract'
          operands: [
            {
              dataset: 'ideal-cut'
              aggregate: 'average'
              attribute: 'price'
            }
            {
              dataset: 'good-cut'
              aggregate: 'average'
              attribute: 'price'
            }
          ]
        }
        {
          operation: 'combine'
          method: 'slice'
          sort: { prop: 'PriceDiff', compare: 'natural', direction: 'descending' }
          limit: 4
        }
      ]

    it "actual complex query with segment filter", ->
      querySpec = [
        {
          "type": "and",
          "filters": [
            {
              "type": "within",
              "attribute": "timestamp",
              "range": [
                new Date("2013-08-17T00:00:00.000Z"),
                new Date("2013-08-24T00:00:00.000Z")
              ]
            },
            {
              "type": "in",
              "attribute": "language",
              "values": [
                "it"
              ]
            }
          ],
          "operation": "filter"
        },
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count",
          "operation": "apply"
        },
        {
          "name": "page",
          "attribute": "page",
          "bucket": "identity",
          "operation": "split"
        },
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count",
          "operation": "apply"
        },
        {
          "operation": "combine",
          "method": "slice",
          "sort": {
            "compare": "natural",
            "prop": "count",
            "direction": "descending"
          },
          "limit": "10"
        },
        {
          "name": "robot",
          "attribute": "robot",
          "bucket": "identity",
          "operation": "split",
          "segmentFilter": {
            "type": "or",
            "filters": [
              {
                "type": "is",
                "prop": "page",
                "value": "Storia_di_Livorno"
              },
              {
                "type": "is",
                "prop": "page",
                "value": "Utente:Martellodifiume/Sandbox2"
              }
            ]
          }
        },
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count",
          "operation": "apply"
        },
        {
          "operation": "combine",
          "method": "slice",
          "sort": {
            "compare": "natural",
            "prop": "count",
            "direction": "descending"
          },
          "limit": "10"
        }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)

    it "heatmap query", ->
      querySpec = [
        {
          "type": "within",
          "attribute": "timestamp",
          "range": [
            new Date("2013-08-22T00:00:00.000Z"),
            new Date("2013-08-29T00:00:00.000Z")
          ],
          "operation": "filter"
        },
        {
          "bucket": "tuple",
          "splits": [
            {
              "bucket": "identity",
              "name": "user",
              "attribute": "user"
            },
            {
              "bucket": "identity",
              "name": "language",
              "attribute": "language"
            }
          ],
          "operation": "split"
        },
        {
          "name": "count",
          "aggregate": "sum",
          "attribute": "count",
          "operation": "apply"
        },
        {
          "method": "matrix",
          "sort": {
            "compare": "natural",
            "prop": "count",
            "direction": "descending"
          },
          "limits": [20, 20],
          "operation": "combine"
        }
      ]
      expect(new FacetQuery(querySpec).valueOf()).to.deep.equal(querySpec)



