chai = require("chai")
expect = chai.expect
utils = require('../utils')

{ simpleLocator } = require('../../build/locator/simpleLocator')

{ druidRequester } = require('../../build/requester/druidRequester')
{ mySqlRequester } = require('../../build/requester/mySqlRequester')
# hadoopRequester = require('../mocks/hadoopRequester')

{ simpleDriver } = require('../../build/driver/simpleDriver')
{ sqlDriver } = require('../../build/driver/sqlDriver')
{ druidDriver } = require('../../build/driver/druidDriver')
# hadoopDriver = require('../../src_old/driver/hadoopDriver')

# Set up drivers
driverFns = {}
verbose = false

# Simple
diamondsData = require('../../data/diamonds.js')
driverFns.simple = simpleDriver(diamondsData)

# MySQL
sqlPass = mySqlRequester({
  locator: simpleLocator('localhost')
  database: 'facet'
  user: 'facet_user'
  password: 'HadleyWickham'
})

sqlPass = utils.wrapVerbose(sqlPass, 'MySQL') if verbose

driverFns.mySql = sqlDriver({
  requester: sqlPass
  table: 'diamonds'
  filters: null
})

# # Druid
# druidPass = druidRequester({
#   locator: simpleLocator('10.186.40.119')
#   port: 8080
# })

# driverFns.druid = druidDriver({
#   requester: druidPass
#   dataSource: context.dataSource
#   filter: null
# })

# Hadoop

# hadoopPass = hadoopRequester(diamondsData)
#
# driverFns.hadoop = hadoopDriver({
#   requester: hadoopPass
#   path: 's3://metamx-user-scratch/gian/diamonds'
#   filters: null
# })


testEquality = utils.makeEqualityTest(driverFns)


describe "Diamonds dataset", ->
  @timeout(40 * 1000)

  describe "apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'apply', name: 'Count',  aggregate: 'count' }
      ]
    }

  describe "many applies", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'apply', name: 'Constant 42',  aggregate: 'constant', value: '42' }
        { operation: 'apply', name: 'Count',  aggregate: 'count' }
        { operation: 'apply', name: 'Total Price',  aggregate: 'sum', attribute: 'price' }
        { operation: 'apply', name: 'Avg Price',  aggregate: 'average', attribute: 'price' }
        { operation: 'apply', name: 'Min Price',  aggregate: 'min', attribute: 'price' }
        { operation: 'apply', name: 'Max Price',  aggregate: 'max', attribute: 'price' }
        { operation: 'apply', name: 'Num Cuts',  aggregate: 'uniqueCount', attribute: 'cut' }
      ]
    }

  describe.skip "filter applies", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'apply', name: 'Constant 42',  aggregate: 'constant', value: '42',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Count',  aggregate: 'count',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Total Price',  aggregate: 'sum', attribute: 'price',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Avg Price',  aggregate: 'average', attribute: 'price',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Min Price',  aggregate: 'min', attribute: 'price',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Max Price',  aggregate: 'max', attribute: 'price',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
        {
          operation: 'apply', name: 'Num Cuts',  aggregate: 'uniqueCount', attribute: 'cut',
          filter: { attribute: 'color', type: 'is', value: 'E' }
        }
      ]
    }

  describe "split cut; no apply", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "split cut; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "split carat; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Carat', compare: 'natural', direction: 'ascending' } }
      ]
    }

  describe "split cut; apply count > split color; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }

        { operation: 'split', name: 'Color', bucket: 'identity', attribute: 'color' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Color', compare: 'natural', direction: 'descending' }, limit: 2 }
      ]
    }

  describe "split cut; apply count > split color; apply count (filter bucket)", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }

        {
          operation: 'split'
          name: 'Color'
          bucket: 'identity'
          attribute: 'color'
          segmentFilter: { type: 'in', prop: 'Cut', values: ['Ideal', 'Good'] }
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Color', compare: 'natural', direction: 'descending' }, limit: 2 }
      ]
    }

  describe "split cut; apply count > split carat; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }

        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Carat', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "split(1, .5) carat; apply count > split cut; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 1, offset: 0.5, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "split carat; apply count > split cut; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "apply arithmetic", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'apply'
          name: 'Count Plus One'
          arithmetic: 'add'
          operands: [
            { aggregate: 'count' }
            { aggregate: 'constant', value: 1 }
          ]
        }
        {
          operation: 'apply'
          name: 'Price + Carat'
          arithmetic: 'add'
          operands: [
            { aggregate: 'sum', attribute: 'price' }
            { aggregate: 'sum', attribute: 'carat' }
          ]
        }
        {
          operation: 'apply'
          name: 'Price - Carat'
          arithmetic: 'subtract'
          operands: [
            { aggregate: 'sum', attribute: 'price' }
            { aggregate: 'sum', attribute: 'carat' }
          ]
        }
        {
          operation: 'apply'
          name: 'Price * Carat'
          arithmetic: 'multiply'
          operands: [
            { aggregate: 'min', attribute: 'price' }
            { aggregate: 'max', attribute: 'carat' }
          ]
        }
        {
          operation: 'apply'
          name: 'Price / Carat'
          arithmetic: 'divide'
          operands: [
            { aggregate: 'sum', attribute: 'price' }
            { aggregate: 'sum', attribute: 'carat' }
          ]
        }
      ]
    }

  describe "apply arithmetic", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'apply'
          name: 'Count Plus One'
          arithmetic: 'add'
          operands: [
            { aggregate: 'count' }
            { aggregate: 'constant', value: 1 }
          ]
        }
      ]
    }

  describe "filter false; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'filter', type: 'false' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
    }

  describe "filter a && ~a; split carat; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'and'
          filters: [
            { type: 'is', attribute: 'color', value: 'E' }
            { type: 'not', filter: { type: 'is', attribute: 'color', value: 'E' } }
          ]
        }
        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }
      ]
    }

  describe "is filter", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'filter', type: 'is', attribute: 'color', value: 'E' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
    }


  describe "complex filter", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'or'
          filters: [
            { type: 'is', attribute: 'color', value: 'E' }
            {
              type: 'and'
              filters: [
                { type: 'in', attribute: 'clarity', values: ['SI1', 'SI2'] }
                { type: 'not', filter: { type: 'is', attribute: 'cut', value: 'Good' } }
              ]
            }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
      ]
    }

  describe "complex filter; split carat; apply count > split cut; apply count", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        {
          operation: 'filter'
          type: 'or'
          filters: [
            { type: 'is', attribute: 'color', value: 'E' }
            {
              type: 'and'
              filters: [
                { type: 'in', attribute: 'clarity', values: ['SI1', 'SI2'] }
                { type: 'not', filter: { type: 'is', attribute: 'cut', value: 'Good' } }
              ]
            }
          ]
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }

        { operation: 'split', name: 'Carat', bucket: 'continuous', size: 0.1, offset: 0.005, attribute: 'carat' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 5 }

        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
      ]
    }

  describe "segment filter", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
        { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { prop: 'Count', compare: 'natural', direction: 'descending' }, limit: 2 }

        {
          operation: 'split'
          name: 'Clarity', bucket: 'identity', attribute: 'clarity'
          segmentFilter: {
            type: 'in'
            prop: 'Cut'
            values: ['Ideal', 'Strange']
          }
        }
        { operation: 'apply', name: 'Count', aggregate: 'count' }
        { operation: 'combine', method: 'slice', sort: { compare: 'natural', prop: 'Count', direction: 'descending' }, limit: 2 }
      ]
    }

  describe "sort-by-delta", ->
    it "should have the same results for different drivers", testEquality {
      drivers: ['simple', 'mySql']
      query: [
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
    }
