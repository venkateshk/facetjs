chai = require("chai")
expect = chai.expect

{FacetSplit} = require('../../target/query')

describe "split", ->
  describe "error", ->
    it "bad input", ->
      splitSpec = "hello world"
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "unrecognizable split")

    it "no bucket", ->
      splitSpec = {}
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "bucket must be defined")

    it "bad bucket", ->
      splitSpec = { bucket: ['wtf?'] }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "bucket must be a string")

    it "unknown bucket", ->
      splitSpec = { bucket: 'poo' }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "unsupported bucket 'poo'")

    it "bad name", ->
      splitSpec = { bucket: "identity", name: ["wtf?"] }
      expect(-> FacetSplit.fromSpec(splitSpec)).to.throw(Error, "split name must be a string")


  describe "preserves", ->
    it "identity", ->
      splitSpec = {
        name: "something"
        bucket: "identity"
        attribute: "country"
      }
      expect(FacetSplit.fromSpec(splitSpec).valueOf()).to.deep.equal(splitSpec)

    it "identity with bucketFilter", ->
      splitSpec = {
        name: "something"
        bucket: "identity"
        attribute: "country"
        bucketFilter: {
          type: 'is'
          prop: 'continent'
          value: 'Asia'
        }
      }
      expect(FacetSplit.fromSpec(splitSpec).valueOf()).to.deep.equal(splitSpec)

    it "continuous", ->
      splitSpec = {
        name: "Histogram"
        bucket: "continuous"
        attribute: 'bid_hist'
        size: 5
        offset: 1
        options: {
          druidResolution: 200
        }
      }
      expect(FacetSplit.fromSpec(splitSpec).valueOf()).to.deep.equal(splitSpec)

    it "timePeriod", ->
      splitSpec = {
        name: 'Time'
        bucket: 'timePeriod'
        attribute: 'time'
        period: 'PT1H'
        timezone: 'Etc/UTC'
      }
      expect(FacetSplit.fromSpec(splitSpec).valueOf()).to.deep.equal(splitSpec)

    it "tuple", ->
      splitSpec = {
        name: "heatmap"
        bucket: 'tuple'
        splits: [
          {
            bucket: "identity"
            attribute: "attr1"
          }
          {
            bucket: "identity"
            attribute: "attr2"
          }
        ]
      }
      expect(FacetSplit.fromSpec(splitSpec).valueOf()).to.deep.equal(splitSpec)


  describe "getFilterFor", ->
    it "identity", ->
      expect(FacetSplit.fromSpec({
        name: "something"
        bucket: "identity"
        attribute: "country"
      }).getFilterFor("UK").valueOf()).to.deep.equal({
        type: "is"
        attribute: "country"
        value: "UK"
      })

