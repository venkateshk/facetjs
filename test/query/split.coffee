chai = require("chai")
expect = chai.expect

{FacetSplit} = require('../../target/query')

describe "split", ->
  describe "preserves", ->
    it "identity", ->
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

