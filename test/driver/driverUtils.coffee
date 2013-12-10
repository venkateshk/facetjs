chai = require("chai")
expect = chai.expect

driverUtil = require('../../src/driver/driverUtil')
{ Table } = driverUtil
data = require('../data')

describe "Utility", ->
  describe "flatten", ->
    it "should work on an empty list", ->
      expect(driverUtil.flatten([])).to.deep.equal([])

    it "should work on a list of an empty list", ->
      expect(driverUtil.flatten([[]])).to.deep.equal([])

    it "should work on a list of empty lists", ->
      expect(driverUtil.flatten([[], []])).to.deep.equal([])

    it "should work on a normal list", ->
      expect(driverUtil.flatten([[1,3], [3,6,7]])).to.deep.equal([1,3,3,6,7])


  describe "inPlaceTrim", ->
    it "should trim down", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 2)
      expect(a).to.deep.equal([1, 2])

    it "should trim down to 0", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 0)
      expect(a).to.deep.equal([])

    it "should trim above length", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 10)
      expect(a).to.deep.equal([1, 2, 3, 4])


  describe "datesToInterval", ->
    it "should simplify round dates", ->
      expect(driverUtil.datesToInterval(
        new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
        new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
      )).to.equal('2013-02-26/2013-02-27')

    it "should work for general dates", ->
      expect(driverUtil.datesToInterval(
        new Date(Date.UTC(2013, 2 - 1, 26, 1, 1, 1))
        new Date(Date.UTC(2013, 2 - 1, 27, 2, 2, 2))
      )).to.equal('2013-02-26T01:01:01/2013-02-27T02:02:02')


  describe "timeFilterToIntervals", ->
    it "should work for simple within filter", ->
      expect(driverUtil.timeFilterToIntervals({
        type: 'within'
        attribute: 'time'
        range: [
          new Date(Date.UTC(2013, 2 - 1, 26, 0, 0, 0))
          new Date(Date.UTC(2013, 2 - 1, 27, 0, 0, 0))
        ]
      })).to.deep.equal(["2013-02-26/2013-02-27"])


  describe "continuousFloorExpresion", ->
    it "should be minimalistic (no size / no offset)", ->
      expect(driverUtil.continuousFloorExpresion({
        variable: "x"
        floorFn: "Math.floor"
        size: 1
        offset: 0
      })).to.equal('Math.floor(x)')

    it "should be minimalistic (no size)", ->
      expect(driverUtil.continuousFloorExpresion({
        variable: "x"
        floorFn: "Math.floor"
        size: 1
        offset: 0.3
      })).to.equal('Math.floor(x - 0.3) + 0.3')

    it "should be minimalistic (no offset)", ->
      expect(driverUtil.continuousFloorExpresion({
        variable: "x"
        floorFn: "Math.floor"
        size: 5
        offset: 0
      })).to.equal('Math.floor(x / 5) * 5')

    it "should be work in general", ->
      expect(driverUtil.continuousFloorExpresion({
        variable: "x"
        floorFn: "Math.floor"
        size: 5
        offset: 3
      })).to.equal('Math.floor((x - 3) / 5) * 5 + 3')


  describe "Table", ->
    describe "should produce the same result", ->
      it "Basic Rectangular Table", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new Table({
          root
          query
        })

        expect(["Cut", "Count"]).to.deep.equal(table.columns, "Columns of the table is incorrect")

        expect(table.data).to.deep.equal([
          { Count: 1, Cut: 'A' }
          { Count: 2, Cut: 'B' }
          { Count: 3, Cut: 'C' }
          { Count: 4, Cut: 'D' }
          { Count: 5, Cut: 'E' }
          { Count: 6, Cut: 'F"' }
        ], "Data of the table is incorrect")

        expect(table.toTabular(',')).to.deep.equal(
          '"Cut","Count"\r\n"A","1"\r\n"B","2"\r\n"C","3"\r\n"D","4"\r\n"E","5"\r\n"F\"\"","6"'
          "CSV of the table is incorrect"
        )

        expect(table.toTabular('\t')).to.deep.equal(
          '"Cut"\t"Count"\r\n"A"\t"1"\r\n"B"\t"2"\r\n"C"\t"3"\r\n"D"\t"4"\r\n"E"\t"5"\r\n"F\"\""\t"6"'
          "TSV of the table is incorrect"
        )

      it "Inheriting properties", ->
        query = data.diamond[2].query
        root = data.diamond[2].data
        table = new Table({
          root
          query
        })

        expect(table.columns).to.deep.equal(["Carat", "Cut", "Count"], "Columns of the table is incorrect")
        expect(table.data).to.deep.equal(data.diamond[2].tabular, "Data of the table is incorrect")
        expect(table.toTabular(',')).to.deep.equal(data.diamond[2].csv, "CSV of the table is incorrect")

      it.skip "Big Data", ->
        query = data.diamond[1].query
        root = {
          prop: { Count: 200000 }
          splits: []
        }
        num = 5000001
        while num -= 1
          root.splits.push { prop: { Cut: 'A', Count: 1 } }

        table = new Table({
          root
          query
        })


    describe "should map the columns correctly", ->
      it "Full Mapping", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new Table({
          root
          query
        })

        table.columnMap (name) ->
          map = {
            "Cut": "Cut_Test"
            "Count": "Count_Test"
          }
          return map[name] or name

        expect(["Cut_Test", "Count_Test"]).to.deep.equal(table.columns, "Columns of the table is incorrect")

        expect(table.toTabular('\t')).to.deep.equal(
          '"Cut_Test"\t"Count_Test"\r\n"A"\t"1"\r\n"B"\t"2"\r\n"C"\t"3"\r\n"D"\t"4"\r\n"E"\t"5"\r\n"F\"\""\t"6"'
          "TSV of the table is incorrect"
        )

      it "Partial Mapping", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new Table({
          root
          query
        })

        table.columnMap (name) ->
          map = {
            "Cut": "Cut_Test"
          }
          return map[name] or name

        expect(["Cut_Test", "Count"]).to.deep.equal(table.columns, "Columns of the table is incorrect")

        expect(table.toTabular('\t')).to.deep.equal(
          '"Cut_Test"\t"Count"\r\n"A"\t"1"\r\n"B"\t"2"\r\n"C"\t"3"\r\n"D"\t"4"\r\n"E"\t"5"\r\n"F\"\""\t"6"'
          "TSV of the table is incorrect"
        )

      it "Over Mapping", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new Table({
          root
          query
        })

        table.columnMap (name) ->
          map = {
            "Cut": "Cut_Test"
            "Count": "Count_Test"
            "Clarity": "Clarity_Test"
          }
          return map[name] or name

        expect(["Cut_Test", "Count_Test"]).to.deep.equal(table.columns, "Columns of the table is incorrect")

        expect(table.toTabular('\t')).to.deep.equal(
          '"Cut_Test"\t"Count_Test"\r\n"A"\t"1"\r\n"B"\t"2"\r\n"C"\t"3"\r\n"D"\t"4"\r\n"E"\t"5"\r\n"F\"\""\t"6"'
          "TSV of the table is incorrect"
        )


