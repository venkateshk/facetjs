{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

fractalCache = require('../../src/driver/fractalCache')
SegmentTree = require('../../src/driver/segmentTree')
{FacetQuery, FacetFilter, ApplySimplifier} = require('../../src/query/index')

{ computeDeltaQuery } = fractalCache

{
  IdentityCombineToSplitValues
  TimePeriodCombineToSplitValues
  ContinuousCombineToSplitValues
} = fractalCache.cacheSlots

toSegmentTreeWithMeta = ({prop, loading, meta, splits}) ->
  rootSegment = new SegmentTree({prop})
  rootSegment['$_' + k] = v for k, v of meta
  rootSegment.markLoading() if loading
  rootSegment.setSplits(splits.map(toSegmentTreeWithMeta)) if splits
  return rootSegment

computeMissingApplies = (applies) ->
  applySimplifier = new ApplySimplifier({
    namePrefix: 'c_S'
    breakToSimple: true
    topLevelConstant: 'process'
  })
  applySimplifier.addApplies(applies)
  simpleApplies = applySimplifier.getSimpleApplies()
  missingApplies = {}
  for apply in simpleApplies
    missingApplies[apply.toHash()] = apply
  return missingApplies

describe "IdentityCombineToSplitValues", ->


describe "TimePeriodCombineToSplitValues", ->


describe "ContinuousCombineToSplitValues", ->


describe "computeDeltaQuery", ->
  facetQuery = new FacetQuery [
    { operation: "filter", type: "is", attribute: "country", value: "USA" }
    { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
    { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
    { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
    { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
    { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
    { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
    { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
    { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
    {
      operation: 'apply'
      name: 'AvgDeleted'
      arithmetic: 'divide'
      operands: [
        { aggregate: 'sum', attribute: 'deleted' }
        { aggregate: 'sum', attribute: 'count' }
      ]
    }
    { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
  ]

  it "generates the full query", ->
    rootSegment = toSegmentTreeWithMeta({
      loading: true
      meta: {
        missingApplies: computeMissingApplies(facetQuery.getCondensedCommands()[0].applies)
      }
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      { operation: "filter", type: "is", attribute: "country", value: "USA" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the full query (no total applies)", ->
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      loading: true
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      { operation: "filter", type: "is", attribute: "country", value: "USA" }
      { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the query for a specific language", ->
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
            Edits: 22
          }
          splits: [
            { prop: { Page: 'Love at first sight',  Count: 3, Edits: 6 } }
            { prop: { Page: 'Love at second sight', Count: 2, Edits: 4 } }
          ]
        }
        {
          prop: {
            Language: 'Spanish'
          }
          loading: true
          meta: {
            missingApplies: computeMissingApplies(facetQuery.getCondensedCommands()[1].applies)
          }
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
            Edits: 18
          }
          splits: [
            { prop: { Page: 'Ahava bemabat rishon', Count: 3, Edits: 6 } }
            { prop: { Page: 'Ahava bemabat sheni',  Count: 2, Edits: 4 } }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      {
        operation: "filter"
        type: "and"
        filters: [
          { type: "is", attribute: "country", value: "USA" }
          { type: "is", attribute: "language", value: "Spanish" }
        ]
      }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the query for a specific language (no total applies)", ->
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
            Edits: 22
          }
          splits: [
            { prop: { Page: 'Love at first sight',  Count: 3, Edits: 6 } }
            { prop: { Page: 'Love at second sight', Count: 2, Edits: 4 } }
          ]
        }
        {
          prop: {
            Language: 'Spanish'
            Count: 10
            Edits: 20
          }
          loading: true
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
            Edits: 18
          }
          splits: [
            { prop: { Page: 'Ahava bemabat rishon', Count: 3, Edits: 6 } }
            { prop: { Page: 'Ahava bemabat sheni',  Count: 2, Edits: 4 } }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      {
        operation: "filter"
        type: "and"
        filters: [
          { type: "is", attribute: "country", value: "USA" }
          { type: "is", attribute: "language", value: "Spanish" }
        ]
      }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the query for a specific language and page", ->
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
            Edits: 22
          }
          splits: [
            { prop: { Page: 'Love at first sight',  Count: 3, Edits: 6, AvgDeleted: 1 } }
            { prop: { Page: 'Love at second sight', Count: 2, Edits: 4, AvgDeleted: 1 } }
          ]
        }
        {
          prop: {
            Language: 'Spanish'
            Count: 10
            Edits: 20
          }
          splits: [
            { prop: { Page: 'El love at first sight',  Count: 3, Edits: 6, AvgDeleted: 1 } }
            {
              prop: { Page: 'El love at second sight' }
              loading: true
              meta: {
                missingApplies: computeMissingApplies(facetQuery.getCondensedCommands()[2].applies)
              }
            }
          ]
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
            Edits: 18
          }
          splits: [
            { prop: { Page: 'Ahava bemabat rishon', Count: 3, Edits: 6, AvgDeleted: 1 } }
            { prop: { Page: 'Ahava bemabat sheni',  Count: 2, Edits: 4, AvgDeleted: 1 } }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      {
        operation: "filter"
        type: "and"
        filters: [
          { type: "is", attribute: "country", value: "USA" }
          { type: "is", attribute: "language", value: "Spanish" }
          { type: 'is', attribute: 'page', value: 'El love at second sight' }
        ]
      }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
    ])

  it "generates the query for a specific language and two pages", ->
    missingApplies = computeMissingApplies(facetQuery.getCondensedCommands()[2].applies)
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
            Edits: 22
          }
          splits: [
            { prop: { Page: 'Love at first sight',  Count: 3, Edits: 6, AvgDeleted: 1 } }
            { prop: { Page: 'Love at second sight', Count: 2, Edits: 4, AvgDeleted: 1 } }
          ]
        }
        {
          prop: {
            Language: 'Spanish'
            Count: 10
            Edits: 20
          }
          splits: [
            {
              prop: { Page: 'El love at first sight' }
              loading: true
              meta: { missingApplies }
            }
            {
              prop: { Page: 'El love at second sight' }
              loading: true
              meta: { missingApplies }
            }
          ]
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
            Edits: 18
          }
          splits: [
            { prop: { Page: 'Ahava bemabat rishon', Count: 3, Edits: 6, AvgDeleted: 1 } }
            { prop: { Page: 'Ahava bemabat sheni',  Count: 2, Edits: 4, AvgDeleted: 1 } }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      {
        operation: "filter"
        type: "and"
        filters: [
          { type: "is", attribute: "country", value: "USA" }
          { type: "is", attribute: "language", value: "Spanish" }
          { type: 'in', attribute: 'page', values: ['El love at first sight', "El love at second sight"] }
        ]
      }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the query when everything is missing an apply", ->
    missingApplies = computeMissingApplies([facetQuery.getCondensedCommands()[0].applies[0]])
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
      }
      loading: true
      meta: { missingApplies }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
          }
          loading: true
          meta: { missingApplies }
          splits: [
            {
              prop: { Page: 'Love at first sight',  Count: 6 }
              loading: true
              meta: { missingApplies }
            }
            {
              prop: { Page: 'Love at second sight', Count: 4 }
              loading: true
              meta: { missingApplies }
            }
          ]
        }
        {
          prop: {
            Language: 'Spanish'
            Count: 10
          }
          loading: true
          meta: { missingApplies }
          splits: [
            {
              prop: { Page: 'El love at first sight',  Count: 3 }
              loading: true
              meta: { missingApplies }
            }
            {
              prop: { Page: 'El love at second sight', Count: 2 }
              loading: true
              meta: { missingApplies }
            }
          ]
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
          }
          loading: true
          meta: { missingApplies }
          splits: [
            {
              prop: { Page: 'Ahava bemabat rishon', Count: 6 }
              loading: true
              meta: { missingApplies }
            }
            {
              prop: { Page: 'Ahava bemabat sheni',  Count: 4 }
              loading: true
              meta: { missingApplies }
            }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      { operation: "filter", type: "is", attribute: "country", value: "USA" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

  it "generates the query when lower limits are missing different things", ->
    missingApplies = computeMissingApplies([facetQuery.getCondensedCommands()[0].applies[0]])
    rootSegment = toSegmentTreeWithMeta({
      prop: {
        Count: 100
        Edits: 200
      }
      splits: [
        {
          prop: {
            Language: 'English'
            Count: 11
            Edits: 22
          }
          loading: true
        }
        {
          prop: {
            Language: 'Spanish'
            Count: 10
            Edits: 20
          }
          splits: [
            {
              prop: { Page: 'El love at first sight',  Count: 3 }
              loading: true
              meta: { missingApplies }
            }
            {
              prop: { Page: 'El love at second sight', Count: 2 }
              loading: true
              meta: { missingApplies }
            }
          ]
        }
        {
          prop: {
            Language: 'Hebrew'
            Count: 9
            Edits: 18
          }
          splits: [
            { prop: { Page: 'Ahava bemabat rishon', Count: 3, Edits: 6 } }
            { prop: { Page: 'Ahava bemabat sheni',  Count: 2, Edits: 4 } }
          ]
        }
      ]
    })
    deltaQuery = computeDeltaQuery(facetQuery, rootSegment)
    expect(deltaQuery.valueOf()).to.deep.equal([
      {
        operation: "filter"
        type: "and"
        filters: [
          { type: "is", attribute: "country", value: "USA" }
          { type: "in", attribute: "language", values: ["English", "Spanish"] }
        ]
      }
      { operation: "split", name: "Language", bucket: "identity", attribute: "language" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
      { operation: "split", name: "Page", bucket: "identity", attribute: "page" }
      { operation: "apply", name: "Count", aggregate: "sum", attribute: "count" }
      { operation: "apply", name: "Edits", aggregate: "sum", attribute: "edits" }
      { operation: 'apply', name: 'c_S1_AvgDeleted', aggregate: 'sum', attribute: 'deleted' }
      { operation: "combine", method: "slice", sort: { compare: "natural", prop: "Count", direction: "descending" }, limit: 10 }
    ])

###
ToDo:
  - Fix dataset in splits
  - Test query on multi-dataset Identity split (instead of parallel)
###
