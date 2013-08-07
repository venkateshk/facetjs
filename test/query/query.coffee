chai = require("chai")
expect = chai.expect

{FacetQuery} = require('../../target/query')

describe "query", ->
  describe "preserves", ->
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




