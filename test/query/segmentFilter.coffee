chai = require("chai")
expect = chai.expect

SegmentTree = require('../../src/driver/segmentTree')
{FacetSegmentFilter} = require('../../src/query')

describe "FacetSegmentFilter", ->
  describe "errors", ->
    it "missing type", ->
      segmentSilterSpec = {}
      expect(-> FacetSegmentFilter.fromSpec(segmentSilterSpec)).to.throw(Error, "type must be defined")

    it "invalid type in filter", ->
      segmentSilterSpec = { type: ['wtf?'] }
      expect(-> FacetSegmentFilter.fromSpec(segmentSilterSpec)).to.throw(Error, "type must be a string")

    it "unknown type in filter", ->
      segmentSilterSpec = { type: 'poo' }
      expect(-> FacetSegmentFilter.fromSpec(segmentSilterSpec)).to.throw(Error, "unsupported segment filter type 'poo'")


  describe "filterFunction", ->
    segment = new SegmentTree({
      prop: { 'Country': 'USA' }
      splits: [
        { prop: { 'City': 'San Francisco' } }
        { prop: { 'City': '' } }
        { prop: { 'City': 'San Jose' } }
        { prop: { 'City': null } }
      ]
    })

    it "works with 'San Francisco'", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: 'San Francisco'
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with 'London'", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: 'London'
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(0)

    it "works with ''", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: ""
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with null", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: null
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with parent", ->
      segmentSilterSpec = {
        type: "is",
        prop: "Country",
        value: "USA"
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(4)


  describe "filterFunction (works with time)", ->
    segment = new SegmentTree({
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
      segmentSilterSpec = {
        type: "is",
        prop: "Time",
        value: [
          "2013-02-26T15:00:00.000Z",
          "2013-02-26T16:00:00.000Z"
        ]
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

    it "works with bad time", ->
      segmentSilterSpec = {
        type: "is",
        prop: "Time",
        value: [
          "2013-02-26T15:00:00.000Z",
          "2013-02-26T16:00:01.000Z"
        ]
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(0)

    it "works with null", ->
      segmentSilterSpec = {
        type: "is",
        prop: "Time",
        value: null
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segment.splits.filter(filterFn).length).to.equal(1)

