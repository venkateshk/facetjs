chai = require("chai")
expect = chai.expect
driverUtil = require('../../../target/driverUtil')
data = require('../data')

describe "Utility tests", ->
  describe "flatten", ->
    it "should work on an empty list", ->
      expect(driverUtil.flatten([])).to.deep.equal([])

    it "should work on a a list of empty lists", ->
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

  describe "Table", ->
    describe "should produce the same result", ->
      it "Basic Rectangular Table", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new driverUtil.Table {
          root
          query
        }

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
        table = new driverUtil.Table {
          root
          query
        }

        expect(table.columns).to.deep.equal(["Carat", "Cut", "Count"], "Columns of the table is incorrect")
        expect(table.data).to.deep.equal(data.diamond[2].tabular, "Data of the table is incorrect")
        expect(table.toTabular(',')).to.deep.equal(data.diamond[2].csv, "CSV of the table is incorrect")

    describe "should map the columns correctly", ->
      it "Full Mapping", ->
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new driverUtil.Table {
          root
          query
        }

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
        table = new driverUtil.Table {
          root
          query
        }

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
        table = new driverUtil.Table {
          root
          query
        }

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


  describe "simplify filter", ->
    it "it keeps regular filters unchanged", ->
      expect(driverUtil.simplifyFilter({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      })).to.deep.equal({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      })

    it "flattens (and sorts) nested ANDs", ->
      expect(driverUtil.simplifyFilter({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'and'
            filters: [
              {
                type: 'is'
                attribute: 'country'
                value: 'USA'
              }
              {
                type: 'and'
                filters: [
                  {
                    type: 'is'
                    attribute: 'moon'
                    value: 'new'
                  }
                  {
                    type: 'within'
                    attribute: 'age'
                    range: [5, 90]
                  }
                ]
              }
            ]
          }
        ]
      })).to.deep.equal({
        type: 'and'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [5, 90]
          }
          {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
          {
            type: 'is'
            attribute: 'moon'
            value: 'new'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      })

    it "flattens (and sorts) nested ORs", ->
      expect(driverUtil.simplifyFilter({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'or'
            filters: [
              {
                type: 'is'
                attribute: 'country'
                value: 'USA'
              }
              {
                type: 'or'
                filters: [
                  {
                    type: 'is'
                    attribute: 'moon'
                    value: 'new'
                  }
                  {
                    type: 'within'
                    attribute: 'age'
                    range: [5, 90]
                  }
                ]
              }
            ]
          }
        ]
      })).to.deep.equal({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [5, 90]
          }
          {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
          {
            type: 'is'
            attribute: 'moon'
            value: 'new'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      })

  describe 'filterToString', ->
    it 'properly translates is filter', ->
      filter = {
        type: 'is'
        attribute: 'Color'
        value: 'Red'
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color is Red')
      return

    it 'properly translates in filter', ->
      filter = {
        type: 'in'
        attribute: 'Color'
        values: ['Red']
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color is Red')

      filter = {
        type: 'in'
        attribute: 'Color'
        values: ['Red', 'Blue']
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color is either Red or Blue')

      filter = {
        type: 'in'
        attribute: 'Color'
        values: ['Red', 'Blue', 'Green']
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color is one of: Red, Blue, or Green')
      return

    it 'properly translates fragements filter', ->
      filter = {
        type: 'fragments'
        attribute: 'Color'
        fragments: ['Red', 'Blue']
      }
      expect(driverUtil.filterToString(filter)).to.equal("'Color contains 'Red', 'Blue'")
      return

    it 'properly translates match filter', ->
      filter = {
        type: 'match'
        attribute: 'Color'
        match: "^R"
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color matches /^R/')
      return

    it 'properly translates within filter', ->
      filter = {
        type: 'within'
        attribute: 'Number'
        range: [1, 10]
      }
      expect(driverUtil.filterToString(filter)).to.equal('Number is within 1 and 10')

      filter = {
        type: 'within'
        attribute: 'Time'
        range: ["2013-07-09T20:30:40.251Z", "2014-07-09T20:30:40.251Z"]
      }
      expect(driverUtil.filterToString(filter)).to.equal("Time is within 2013-07-09T20:30:40.251Z and 2014-07-09T20:30:40.251Z")
      return

    it 'properly translates not filter', ->
      filter = {
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'Color'
          value: 'Red'
        }
      }
      expect(driverUtil.filterToString(filter)).to.equal('not (Color is Red)')
      return

    it 'properly translates and filter', ->
      filter = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'Color'
            values: ['Red', 'Blue']
          }
        ]
      }
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) and (Color is in Red,Blue)")
      return

    it 'properly translates or filter', ->
      filter = {
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'Color'
            values: ['Red', 'Blue']
          }
        ]
      }
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) or (Color is in Red,Blue)")

      return

    it 'handles bad filter type', ->
      filter = {
        type: 'hello'
        attribute: 'Color'
        value: 'Red'
      }
      testFn = () ->
        return driverUtil.filterToString(filter)
      expect(testFn).to.throw(TypeError, 'bad filter type')
      return

    it 'properly translates nested filter 1', ->
      filter = {
        type: 'not'
        filter: {
          type: 'or'
          filters: [
            {
              type: 'is'
              attribute: 'Color'
              value: 'Red'
            }
            {
              type: 'in'
              attribute: 'Color'
              values: ['Red', 'Blue']
            }
          ]
        }
      }
      expect(driverUtil.filterToString(filter)).to.equal("not ((Color is Red) or (Color is in Red,Blue))")

      return

    it 'properly translates nested filter 2', ->
      filter = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'Color'
            values: ['Red', 'Blue']
          }
          {
            type: 'not'
            filter: {
              type: 'is'
              attribute: 'Color'
              value: 'Red'
            }
          }
        ]
      }
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) and (Color is in Red,Blue) and (not (Color is Red))")

      return
