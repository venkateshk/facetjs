chai = require("chai")
expect = chai.expect
utils = require('../utils')

simpleDriver = require('../../build/simpleDriver')
nestedCache = require('../../build/nestedCache')

{FacetQuery} = require('../../build/query')

wikipediaData = require('../../data/wikipedia.js')

allowQuery = true
checkEquality = false
expectedQuery = null

driverFns = {}
driverFns.wikipediaSimple = wikipediaSimple = simpleDriver(wikipediaData)

disown = (root) ->
  newRoot = {}
  newRoot.prop = root.prop if root.prop
  newRoot.splits = root.splits.map(disown) if root.splits
  return newRoot

nestedCacheCallback = null
nestedCacheInstance = nestedCache({
  transport: (request, callback) ->
    if checkEquality
      expect(request.query.valueOf()).to.deep.equal(expectedQuery)

    if not allowQuery
      throw new Error("query not allowed")

    wikipediaSimple(request, callback)
    return
  onData: (data, state) ->
    return unless state is 'final'
    nestedCacheCallback(null, disown(data))
    nestedCacheCallback = null
    return
})

driverFns.wikipediaCached = (query, callback) ->
  nestedCacheCallback = callback
  nestedCacheInstance(query)
  return


testEquality = utils.makeEqualityTest(driverFns)

describe "Nested cache", ->
  it "apply Revenue", testEquality {
    drivers: ['wikipediaSimple', 'wikipediaCached']
    query: [
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
    ]
  }

  it "split Color; apply Revenue; combine descending", testEquality {
    drivers: ['wikipediaSimple', 'wikipediaCached']
    query: [
      { operation: 'filter', type: 'within', attribute: 'time', range: [new Date(Date.UTC(2013, 2-1, 26, 0, 0, 0)), new Date(Date.UTC(2013, 2-1, 27, 0, 0, 0))] }
      { operation: 'split', name: 'Time', bucket: 'timePeriod', attribute: 'time', period: 'PT1H', timezone: 'Etc/UTC' }
      { operation: 'apply', name: 'Count', aggregate: 'sum', attribute: 'count' }
      { operation: 'combine', combine: 'slice', sort: { compare: 'natural', prop: 'Time', direction: 'ascending' } }
    ]
  }
