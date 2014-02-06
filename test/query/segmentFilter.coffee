chai = require("chai")
expect = chai.expect

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
    parentSegment = {
      prop: {
        'Country': 'USA'
      }
    }
    segments = [
      {
        parent: parentSegment
        prop: {
          'City': 'San Francisco'
        }
      }
      {
        parent: parentSegment
        prop: {
          'City': ''
        }
      }
      {
        parent: parentSegment
        prop: {
          'City': 'San Jose'
        }
      }
    ]
    parentSegment.splits = segments

    it "works with 'San Francisco'", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: 'San Francisco'
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segments.filter(filterFn).length).to.equal(1)

    it "works with 'London'", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: 'London'
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segments.filter(filterFn).length).to.equal(0)

    it "works with ''", ->
      segmentSilterSpec = {
        type: "is",
        prop: "City",
        value: ""
      }
      filterFn = FacetSegmentFilter.fromSpec(segmentSilterSpec).getFilterFn()
      expect(segments.filter(filterFn).length).to.equal(1)








