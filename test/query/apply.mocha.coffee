{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{FacetApply, DivideApply, SumApply, CountApply} = require('../../build/query/apply')

describe "FacetApply", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetApply, [
      {
        name: "Count"
        aggregate: 'constant'
        value: 42
      }
      {
        name: "Count"
        aggregate: 'count'
      }
      {
        name: "Count"
        dataset: 'mydata'
        aggregate: 'count'
      }
      {
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
      {
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
      {
        aggregate: "sum"
        attribute: "count"
      }
      {
        aggregate: "sum"
        attribute: "count"
        dataset: 'moon'
      }
      {
        dataset: "somedata"
        arithmetic: "multiply"
        operands: [
          {
            aggregate: "max"
            attribute: "value"
          }
          {
            aggregate: "min"
            attribute: "count"
          }
        ]
      }
      {
        arithmetic: "divide"
        operands: [
          {
            aggregate: "max"
            attribute: "value"
          }
          {
            aggregate: "min"
            attribute: "count"
          }
        ]
      }
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
    ], {
      newThrows: true
    })

  describe "error", ->
    it "throws on bad input", ->
      applySpec = "hello world"
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "unrecognizable apply")

    it "throws on no aggregate or arithmetic", ->
      applySpec = {}
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "must have an aggregate or arithmetic")

    it "throws on bad aggregate", ->
      applySpec = { aggregate: ['wtf?'] }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "aggregate must be a string")

    it "throws on bad arithmetic", ->
      applySpec = { arithmetic: ['wtf?'] }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "arithmetic must be a string")

    it "throws on unknown aggregate", ->
      applySpec = { aggregate: 'poo' }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "unsupported aggregate 'poo'")

    it "throws on unknown arithmetic", ->
      applySpec = { arithmetic: 'poo' }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "unsupported arithmetic 'poo'")

    it "throws on bad name", ->
      applySpec = { aggregate: 'count', name: ["wtf?"] }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "apply name must be a string")

    it "throws on bad attribute", ->
      applySpec = { aggregate: 'sum', attribute: ["wtf?"] }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "attribute must be a string")

    it "throws on constant without value", ->
      applySpec = { name: "Const", aggregate: 'constant' }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "constant apply must have a numeric value")

    it "throws on constant with bad value", ->
      applySpec = { name: "Const", aggregate: 'constant', value: null }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "constant apply must have a numeric value")

      applySpec = { name: "Const", aggregate: 'constant', value: NaN }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "constant apply must have a numeric value")

      applySpec = { name: "Const", aggregate: 'constant', value: "wtf?" }
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "constant apply must have a numeric value")

    it "throws on dataset conflict", ->
      applySpec = {
        name: "lag"
        dataset: "somedata"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            operands: [
              {
                dataset: "somedata"
                aggregate: "sum"
                attribute: "value"
              }
              {
                dataset: "otherdata"
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
      expect(-> FacetApply.fromJS(applySpec)).to.throw(Error, "dataset conflict between 'somedata' and 'otherdata'")


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
      expect(FacetApply.fromJS(applySpec).toJS()).to.deep.equal(applySpec)

    it "filtered", ->
      applySpec = {
        name: "Count R=0"
        aggregate: "sum", attribute: "count"
        filter: { type: 'is', attribute: "robot", value: "0" }
      }
      expect(FacetApply.fromJS(applySpec).toJS()).to.deep.equal(applySpec)

    it "constant dataset", ->
      applySpec = {
        name: 'Const'
        aggregate: "constant"
        value: 3600
        dataset: 'somedata'
      }
      expect(FacetApply.fromJS(applySpec).toJS()).to.deep.equal({
        name: 'Const'
        aggregate: "constant"
        value: 3600
      })

    it "complex with dataset", ->
      applySpec = {
        name: "lag"
        arithmetic: "divide"
        operands: [
          {
            arithmetic: "divide"
            dataset: "somedata"
            operands: [
              {
                dataset: "somedata"
                aggregate: "sum"
                attribute: "value"
              }
              {
                dataset: "somedata"
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
      expect(FacetApply.fromJS(applySpec).toJS()).to.deep.equal({
        name: "lag"
        arithmetic: "divide"
        dataset: "somedata"
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
      })

    it "complex multi-dataset", ->
      applySpec = {
        name: 'EditsDiff'
        arithmetic: 'subtract'
        operands: [
          { dataset: 'humans', aggregate: 'sum', attribute: 'count' }
          { dataset: 'robots', aggregate: 'sum', attribute: 'count' }
        ]
      }
      expect(FacetApply.fromJS(applySpec).toJS()).to.deep.equal(applySpec)


  describe "toString", ->
    it "complex divide", ->
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
      expect(FacetApply.fromJS(applySpec).toString()).to.equal("lag <- (sum(`value`) / sum(`count`)) / 3600")

    it "complex multiply", ->
      applySpec = {
        name: "lag"
        arithmetic: "multiply"
        operands: [
          {
            arithmetic: "multiply"
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
      expect(FacetApply.fromJS(applySpec).toString()).to.equal("lag <- sum(`value`) * sum(`count`) * 3600")


  describe "getAttributes", ->
    it "works on constant", ->
      applySpec = {
        aggregate: "constant"
        value: 3600
      }
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal([])

    it "works on count", ->
      applySpec = {
        aggregate: "count"
      }
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal([])

    it "works on basic example", ->
      applySpec = {
        aggregate: "sum"
        attribute: "count"
      }
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal(["count"])

    it "works on a complex example", ->
      applySpec = {
        arithmetic: "multiply"
        operands: [
          {
            aggregate: "max"
            attribute: "value"
          }
          {
            aggregate: "min"
            attribute: "count"
          }
        ]
      }
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal(["count", "value"])

    it "works on an overlapping complex example", ->
      applySpec = {
        arithmetic: "multiply"
        operands: [
          {
            aggregate: "max"
            attribute: "value"
          }
          {
            aggregate: "min"
            attribute: "value"
          }
        ]
      }
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal(["value"])

    it "works in a deep nested example", ->
      applySpec = {
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
      expect(FacetApply.fromJS(applySpec).getAttributes()).to.deep.equal(["count", "value"])

  describe "getDataset", ->
    it "basically works", ->
      applySpec = {
        name: "lag"
        aggregate: "sum"
        attribute: "value"
        dataset: 'somedata'
      }
      expect(FacetApply.fromJS(applySpec).getDataset()).to.equal('somedata')

    it "works for arithmetic applies", ->
      applySpec = {
        operation: 'apply'
        name: 'PriceDiff'
        arithmetic: 'subtract'
        operands: [
          {
            dataset: 'ideal-cut'
            aggregate: 'average'
            attribute: 'price'
          }
          {
            dataset: 'good-cut'
            aggregate: 'average'
            attribute: 'price'
          }
        ]
      }
      apply = FacetApply.fromJS(applySpec)
      expect(apply.getDataset()).to.equal('good-cut')
      expect(apply.getDatasets()).to.deep.equal(['good-cut', 'ideal-cut'])

    it "propagates dataset", ->
      applySpec = {
        name: "lag"
        arithmetic: "multiply"
        dataset: 'somedata'
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
      apply = FacetApply.fromJS(applySpec)
      expect(apply.getDataset()).to.equal('somedata')
      expect(apply.operands[0].getDataset()).to.equal('somedata')
      expect(apply.operands[0].toJS()).to.deep.equal({
        aggregate: "sum"
        attribute: "value"
        dataset: "somedata"
      })
