chai = require("chai")
expect = chai.expect

{
  FacetApply
} = require('../../target/query')

describe "apply", ->
  it "preserves inputs", ->
    expect(FacetApply.fromSpec({
      name: "p99"
      aggregate: 'quantile'
      attribute: 'bid_hist'
      quantile: 0.99
      options: {
        druidLowerLimit: 0
        druidLowerUpper: 10
        druidResolution: 200
      }
    }).valueOf()).to.deep.equal({
      name: "p99"
      aggregate: 'quantile'
      attribute: 'bid_hist'
      quantile: 0.99
      options: {
        druidLowerLimit: 0
        druidLowerUpper: 10
        druidResolution: 200
      }
    })
