chai = require("chai")
expect = chai.expect

{FacetApply} = require('../../target/query')

describe "apply", ->
  describe "error", ->
    it "bad input", ->
      applySpec = "hello world"
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unrecognizable apply")

    it "no aggregate or arithmetic", ->
      applySpec = {}
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "must have an aggregate or arithmetic")

    it "bad aggregate", ->
      applySpec = { aggregate: ['wtf?'] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "aggregate must be a string")

    it "bad arithmetic", ->
      applySpec = { arithmetic: ['wtf?'] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "arithmetic must be a string")

    it "unknown aggregate", ->
      applySpec = { aggregate: 'poo' }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unsupported aggregate 'poo'")

    it "unknown arithmetic", ->
      applySpec = { arithmetic: 'poo' }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "unsupported arithmetic 'poo'")

    it "bad name", ->
      applySpec = { aggregate: 'count', name: ["wtf?"] }
      expect(-> FacetApply.fromSpec(applySpec)).to.throw(Error, "apply name must be a string")


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

    it "filtered", ->
      applySpec = {
        name: "Count R=0"
        aggregate: "sum", attribute: "count"
        filter: { type: 'is', attribute: "robot", value: "0" }
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























