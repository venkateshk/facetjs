{expect} = require("chai")

{AttributeMeta} = require('../../src/query/attributeMeta')

describe "AttributeMeta", ->
  describe "errors", ->
    it "missing type", ->
      attributeMetaSpec = {}
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "type must be defined")

    it "invalid type", ->
      attributeMetaSpec = { type: ['wtf?'] }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "type must be a string")

    it "unknown type", ->
      attributeMetaSpec = { type: 'poo' }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "unsupported attributeMeta type 'poo'")

    it "non-numeric range size", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 'hello'
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`rangeSize` must be a number")

    it "bad range size (<1)", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.03
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`rangeSize` less than 1 must divide 1")

    it "bad range size (>1)", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 1.5
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`rangeSize` greater than 1 must be an integer")

    it "bad digitsBeforeDecimal", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
        digitsBeforeDecimal: 0
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`digitsBeforeDecimal` must be a positive integer")

    it "bad digitsAfterDecimal", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
        digitsAfterDecimal: 1.5
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`digitsAfterDecimal` must be a positive integer")

    it "digitsAfterDecimal too small", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
        digitsAfterDecimal: 1
      }
      expect(-> AttributeMeta.fromJS(attributeMetaSpec)).to.throw(Error, "`digitsAfterDecimal` must be at least 2 to accommodate for a `rangeSize` of 0.05")


  describe "preserves", ->
    it "default", ->
      attributeMetaSpec = {
        type: 'default'
      }
      expect(AttributeMeta.fromJS(attributeMetaSpec).valueOf()).to.deep.equal(attributeMetaSpec)

    it "unique", ->
      attributeMetaSpec = {
        type: 'unique'
      }
      expect(AttributeMeta.fromJS(attributeMetaSpec).valueOf()).to.deep.equal(attributeMetaSpec)

    it "range (simple)", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
      }
      expect(AttributeMeta.fromJS(attributeMetaSpec).valueOf()).to.deep.equal(attributeMetaSpec)

    it "range with digitsAfterDecima", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 3
        separator: ' - '
        digitsAfterDecimal: 2
      }
      expect(AttributeMeta.fromJS(attributeMetaSpec).valueOf()).to.deep.equal(attributeMetaSpec)


  describe "serialize", ->
    it "works with a simple range", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
      }
      attributeMeta = AttributeMeta.fromJS(attributeMetaSpec)
      expect(attributeMeta.serialize([0.05, 0.1])).to.equal('0.05;0.1')
      expect(attributeMeta.serialize([null, 0])).to.equal(';0')
      expect(attributeMeta.serialize([100, null])).to.equal('100;')

    it "works with a range with digitsAfterDecimal", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
        separator: '::'
        digitsAfterDecimal: 2
      }
      attributeMeta = AttributeMeta.fromJS(attributeMetaSpec)
      expect(attributeMeta.serialize([0.05, 0.1])).to.equal('0.05::0.10')
      expect(attributeMeta.serialize([null, 0])).to.equal('::0.00')
      expect(attributeMeta.serialize([100, null])).to.equal('100.00::')

    it "works with a range with digitsBeforeDecimal + digitsAfterDecimal", ->
      attributeMetaSpec = {
        type: 'range'
        rangeSize: 0.05
        separator: '/'
        digitsBeforeDecimal: 4
        digitsAfterDecimal: 3
      }
      attributeMeta = AttributeMeta.fromJS(attributeMetaSpec)
      expect(attributeMeta.serialize([0.05, 0.1])).to.equal('0000.050/0000.100')
      expect(attributeMeta.serialize([null, 0])).to.equal('/0000.000')
      expect(attributeMeta.serialize([100, null])).to.equal('0100.000/')

    it "throws error for unique", ->
      attributeMetaSpec = {
        type: 'unique'
      }
      attributeMeta = AttributeMeta.fromJS(attributeMetaSpec)
      expect(-> attributeMeta.serialize('lol')).to.throw(Error, 'can not serialize an approximate unique value')


  describe "back compat.", ->
    it "range size", ->
      attributeMetaSpec = {
        type: 'range'
        size: 0.05
      }
      expect(AttributeMeta.fromJS(attributeMetaSpec).valueOf()).to.deep.equal({
        type: 'range'
        rangeSize: 0.05
      })
