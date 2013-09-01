chai = require("chai")
expect = chai.expect

{FacetQuery} = require('../../build/query')

describe "query", ->
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


  describe "errors", ->

    describe "general", ->
      it "bad command", ->
        querySpec = [
          'blah'
        ]
        expect(-> new FacetQuery(querySpec)).to.throw(Error, "unrecognizable command")

      it "no operation in command", ->
        querySpec = [
          {}
        ]
        expect(-> new FacetQuery(querySpec)).to.throw(Error, "operation not defined")

      it "invalid operation in command", ->
        querySpec = [
          { operation: ['wtf?'] }
        ]
        expect(-> new FacetQuery(querySpec)).to.throw(Error, "invalid operation")

      it "unknown operation in command", ->
        querySpec = [
          { operation: 'poo' }
        ]
        expect(-> new FacetQuery(querySpec)).to.throw(Error, "unknown operation 'poo'")

      it "unknown operation in command", ->
        querySpec = [
          { operation: 'combine' }
        ]
        expect(-> new FacetQuery(querySpec)).to.throw(Error, "combine called without split")




