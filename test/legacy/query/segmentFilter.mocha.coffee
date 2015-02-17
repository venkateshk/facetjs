{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ SegmentTree } = facet.legacy
{ FacetSegmentFilter } = facet.legacy

describe "FacetSegmentFilter", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetSegmentFilter, [
      {
        type: "is",
        prop: "City",
        value: 'San Francisco'
      }
      {
        type: "is",
        prop: "Country",
        value: 'USA'
      }
      {
        type: 'not',
        filter: {
          type: "is",
          prop: "City",
          value: 'San Francisco'
        }
      }
      {
        type: 'and'
        filters: [
          {
            type: "is",
            prop: "City",
            value: 'San Francisco'
          }
          {
            type: "is",
            prop: "Country",
            value: 'USA'
          }
        ]
      }
    ], {
      newThrows: true
    })

  describe "errors", ->
    it "missing type", ->
      segmentFilterSpec = {}
      expect(-> FacetSegmentFilter.fromJS(segmentFilterSpec)).to.throw(Error, "type must be defined")

    it "invalid type in filter", ->
      segmentFilterSpec = { type: ['wtf?'] }
      expect(-> FacetSegmentFilter.fromJS(segmentFilterSpec)).to.throw(Error, "type must be a string")

    it "unknown type in filter", ->
      segmentFilterSpec = { type: 'poo' }
      expect(-> FacetSegmentFilter.fromJS(segmentFilterSpec)).to.throw(Error, "unsupported segment filter type 'poo'")


  describe "filterFunction", ->
    segment = SegmentTree.fromJS({
      prop: { 'Country': 'USA' }
      splits: [
        { prop: { 'City': 'San Francisco' } }
        { prop: { 'City': '' } }
        { prop: { 'City': 'San Jose' } }
        { prop: { 'City': null } }
      ]
    })

    it "works with 'San Francisco'", ->
      segmentFilterSpec = {
        type: "is",
        prop: "City",
        value: 'San Francisco'
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with 'London'", ->
      segmentFilterSpec = {
        type: "is",
        prop: "City",
        value: 'London'
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(0)

    it "works with ''", ->
      segmentFilterSpec = {
        type: "is",
        prop: "City",
        value: ""
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with null", ->
      segmentFilterSpec = {
        type: "is",
        prop: "City",
        value: null
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with parent", ->
      segmentFilterSpec = {
        type: "is",
        prop: "Country",
        value: "USA"
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(4)


  describe "filterFunction (works with time)", ->
    segment = SegmentTree.fromJS({
      prop: {
        'Country': 'USA'
      }
      splits: [
        {
          prop: {
            Time: [
              "2013-02-26T16:00:00.000Z",
              "2013-02-26T17:00:00.000Z"
            ]
          }
        }
        {
          prop: {
            Time: [
              "2013-02-26T01:00:00.000Z",
              "2013-02-26T02:00:00.000Z"
            ]
          }
        }
        {
          prop: {
            Time: [
              "2013-02-26T15:00:00.000Z",
              "2013-02-26T16:00:00.000Z"
            ]
          }
        }
        {
          prop: {
            Time: null
          }
        }
      ]
    })

    it "works with IS time", ->
      segmentFilterSpec = {
        type: "is",
        prop: "Time",
        value: [
          "2013-02-26T15:00:00.000Z",
          "2013-02-26T16:00:00.000Z"
        ]
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with bad time", ->
      segmentFilterSpec = {
        type: "is",
        prop: "Time",
        value: [
          "2013-02-26T15:00:00.000Z",
          "2013-02-26T16:00:01.000Z"
        ]
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(0)

    it "works with null", ->
      segmentFilterSpec = {
        type: "is",
        prop: "Time",
        value: null
      }
      filterFn = FacetSegmentFilter.fromJS(segmentFilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

