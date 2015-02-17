{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require("../../../build/facet")
{ FacetSplit } = facet.legacy

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

describe "FacetSplit", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetSplit, [
      {
        name: "something"
        bucket: "identity"
        attribute: "city"
      }
      {
        name: "something"
        bucket: "identity"
        attribute: "country"
        segmentFilter: {
          type: 'is'
          prop: 'continent'
          value: 'Asia'
        }
      }
      {
        name: "Histogram"
        bucket: "continuous"
        attribute: 'bid_hist'
        size: 5
        offset: 1
        lowerLimit: 0
        upperLimit: 100
        options: {
          druidResolution: 200
        }
      }
      {
        name: 'Time'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'PT1H'
        timezone: 'Etc/UTC'
      }
      {
        name: 'Time by Day'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'P1D'
        timezone: 'America/Los_Angeles'
      }
      {
        name: 'TimeWithWarp'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'P1D'
        warp: 'P4D'
        timezone: 'America/Los_Angeles'
      }
      {
        name: 'TimeWithNegativeWarp'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'P1D'
        warp: 'P4D'
        warpDirection: -1
        timezone: 'America/Los_Angeles'
      }
      {
        attribute: "timestamp"
        bucket: "timePeriod"
        name: "time_hour"
        period: "PT1H"
        timezone: "Etc/UTC"
        segmentFilter: {
          type: 'false'
        }
      }
      {
        bucket: 'tuple'
        splits: [
          {
            name: "Attr1"
            bucket: "identity"
            attribute: "attr1"
          }
          {
            name: "Attr2"
            bucket: "identity"
            attribute: "attr2"
          }
        ]
      }
      {
        bucket: 'parallel'
        name: "MySplit"
        splits: [
          {
            bucket: "identity"
            attribute: "attr1"
            dataset: 'd1'
          }
          {
            bucket: "identity"
            attribute: "attr2"
            dataset: 'd2'
          }
        ]
      }
    ], {
      newThrows: true
    })

  describe "error", ->
    it "fails on bad input", ->
      splitSpec = "hello world"
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "unrecognizable split")

    it "fails on no bucket", ->
      splitSpec = {}
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "bucket must be defined")

    it "fails on bad bucket", ->
      splitSpec = { bucket: ['wtf?'] }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "bucket must be a string")

    it "fails on unknown bucket", ->
      splitSpec = { bucket: 'poo' }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "unsupported bucket 'poo'")

    it "fails on bad name", ->
      splitSpec = { bucket: "identity", name: ["wtf?"] }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "split name must be a string")

    it "fails on bad timezone in timePeriod", ->
      splitSpec = { name: 'stuff', attribute: 'something', bucket: "timePeriod", period: 'P1D', timezone: 'UTC' }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "Unable to find time zone named UTC")

    it "fails on bad warp in timePeriod", ->
      splitSpec = { name: 'stuff', attribute: 'something', bucket: "timePeriod", period: 'P1D', timezone: 'Etc/UTC', warp: 'P1K' }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "Can not parse duration 'P1K'")

    it "fails on bad warpDirection in timePeriod", ->
      splitSpec = { name: 'stuff', attribute: 'something', bucket: "timePeriod", period: 'P1D', timezone: 'Etc/UTC', warp: 'P1D', warpDirection: 2 }
      expect(-> FacetSplit.fromJS(splitSpec)).to.throw(Error, "warpDirection must be 1 or -1")

  describe "dataset", ->
    it "returns main", ->
      splitSpec = {
        name: "something"
        bucket: "identity"
        attribute: "country"
      }
      split = FacetSplit.fromJS(splitSpec)
      expect(split.getDataset()).to.equal('main')

  describe "getAttributes", ->
    it "works for simple split", ->
      splitSpec = {
        attribute: "timestamp"
        bucket: "timePeriod"
        name: "time_hour"
        period: "PT1H"
        timezone: "Etc/UTC"
        segmentFilter: {
          type: 'false'
        }
      }
      expect(FacetSplit.fromJS(splitSpec).getAttributes()).to.deep.equal(["timestamp"])

    it "works for tuple split", ->
      splitSpec = {
        bucket: 'tuple'
        splits: [
          {
            name: "Attr1"
            bucket: "identity"
            attribute: "attr1"
          }
          {
            name: "Attr2"
            bucket: "identity"
            attribute: "attr2"
          }
        ]
      }
      expect(FacetSplit.fromJS(splitSpec).getAttributes()).to.deep.equal(["attr1", "attr2"])

    it "works for parallel split (different attributes)", ->
      splitSpec = {
        bucket: 'parallel'
        name: "MySplit"
        splits: [
          {
            bucket: "identity"
            attribute: "attr1"
            dataset: 'd1'
          }
          {
            bucket: "identity"
            attribute: "attr2"
            dataset: 'd2'
          }
        ]
      }
      expect(FacetSplit.fromJS(splitSpec).getAttributes()).to.deep.equal(["attr1", "attr2"])

    it "works for parallel split (same attributes)", ->
      splitSpec = {
        bucket: 'parallel'
        name: "MySplit"
        splits: [
          {
            bucket: "identity"
            attribute: "attr1"
            dataset: 'd1'
          }
          {
            bucket: "identity"
            attribute: "attr1"
            dataset: 'd2'
          }
        ]
      }
      expect(FacetSplit.fromJS(splitSpec).getAttributes()).to.deep.equal(["attr1"])


  describe "getFilterFor", ->
    it "identity", ->
      expect(FacetSplit.fromJS({
        name: "Something"
        bucket: "identity"
        attribute: "country"
      }).getFilterFor({ "Something": "UK" }).valueOf()).to.deep.equal({
        type: "is"
        attribute: "country"
        value: "UK"
      })

