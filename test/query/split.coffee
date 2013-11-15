chai = require("chai")
expect = chai.expect

{FacetSplit} = require('../../build/query')

describe "FacetSplit", ->
  describe "error", ->
    it "fails on bad input", ->
      splitSpec = "hello world"
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "unrecognizable split")

    it "fails on no bucket", ->
      splitSpec = {}
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "bucket must be defined")

    it "fails on bad bucket", ->
      splitSpec = { bucket: ['wtf?'] }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "bucket must be a string")

    it "fails on unknown bucket", ->
      splitSpec = { bucket: 'poo' }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "unsupported bucket 'poo'")

    it "fails on bad name", ->
      splitSpec = { bucket: "identity", name: ["wtf?"] }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "split name must be a string")

    it "fails on bad timezone in timePeriod", ->
      splitSpec = { name: 'stuff', attribute: 'something', bucket: "timePeriod", period: 'P1D', timezone: 'UTC' }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(TypeError, "invalid timezone 'UTC'")

  describe "preserves", ->
    it "identity", ->
      splitSpec = {
        name: "something"
        bucket: "identity"
        attribute: "country"
      }
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)

    it "identity with segmentFilter", ->
      splitSpec = {
        name: "something"
        bucket: "identity"
        attribute: "country"
        segmentFilter: {
          type: 'is'
          prop: 'continent'
          value: 'Asia'
        }
      }
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)

    it "continuous", ->
      splitSpec = {
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
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)

    it "timePeriod", ->
      splitSpec = {
        name: 'Time'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'PT1H'
        timezone: 'Etc/UTC'
      }
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)

    it "timePeriod with segmentFilter", ->
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
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)

    it "tuple", ->
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
      split = FacetSplit.fromSpec(splitSpec)
      expect(split.getDataset()).to.equal('main')
      expect(split.valueOf()).to.deep.equal(splitSpec)


  describe "getFilterFor", ->
    it "identity", ->
      expect(FacetSplit.fromSpec({
        name: "Something"
        bucket: "identity"
        attribute: "country"
      }).getFilterFor({ "Something": "UK" }).valueOf()).to.deep.equal({
        type: "is"
        attribute: "country"
        value: "UK"
      })

