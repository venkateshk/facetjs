chai = require("chai")
expect = chai.expect

{
  FacetApply
} = require('../../target/query')

describe "apply", ->
  describe "preserves", ->
    it "quantile", ->
      applySpec = {
        name: "p99"
        aggregate: 'quantile'
        attribute: 'bid_hist'
        quantile: 0.99
        options: {
          druidLowerLimit: 0
          druidLowerUpper: 10
          druidResolution: 200
        }
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)

    it "complex", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).valueOf()).to.deep.equal(applySpec)


  describe "toString", ->
    it "complex", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                aggregate: "sum"
                attribute: "value"
              }
              {
                aggregate: "sum"
                attribute: "count"
              }
            ]
          }
          {
            aggregate: "constant"
            value: 3600
          }
        ]
      }
      expect(FacetApply.fromSpec(applySpec).toString()).to.equal("lag <- (sum(value) / sum(count)) / 3600")























