{ expect } = require("chai")

facet = require("../../../build/facet")
{ FacetApply } = facet.legacy

describe "parser", ->
  describe "Errors", ->
    it "should throw special error for unmatched ticks", ->
      formula = "sum_hello <- sum(`hello)"
      expect(-> FacetApply.parse(formula)).to.throw(Error, "Unmatched tickmark")

    it "should error if non-alpha characters in attribute if ticks not present", ->
      formula = "sum(hello))"
      expect(-> FacetApply.parse(formula)).to.throw(Error, "Expected [*\\/], [+\\-] or end of input but \")\" found.")

    it "should not allow attributes (w/ ticks) without an aggregate", ->
      formula = "`blah`"
      expect(-> FacetApply.parse(formula)).to.throw(Error, "Expected \"(\", Aggregate or Name but \"`\" found.")

    it "should not allow attributes (w/o ticks) without an aggregate", ->
      formula = "blah"
      expect(-> FacetApply.parse(formula)).to.throw(Error, "Expected \"<-\" but end of input found.")


  describe "Successful parsing", ->
    it "can deal with nameless applies", ->
      formula = "sum(`hello`)"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        aggregate: 'sum'
        attribute: 'hello'
      })

    it "can deal with named applies", ->
      formula = "sum_hello <- sum(`hello`)"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        name: 'sum_hello'
        aggregate: 'sum'
        attribute: 'hello'
      })

    it "handles tickless attributes, with nameless applies", ->
      formula = "sum(hello)"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        aggregate: 'sum'
        attribute: 'hello'
      })

    it "handles tickless attributes, with named applies", ->
      formula = "sum_hello <- sum(hello)"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        name: 'sum_hello'
        aggregate: 'sum'
        attribute: 'hello'
      })

    it "handles other characters in attribute if ticks present", ->
      formula = "sum(`hello)`)"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        aggregate: 'sum'
        attribute: 'hello)'
      })

    it "handles constants", ->
      formula = "3"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        aggregate: 'constant'
        value: 3
      })

    it "handles arithmetic", ->
      formula = "sum(hello) / 3"
      expect(FacetApply.parse(formula).toJS()).to.deep.equal({
        arithmetic: "divide",
        operands: [{
          aggregate: 'sum'
          attribute: 'hello'
        },
        {
          aggregate: 'constant'
          value: 3
        }]
      })
