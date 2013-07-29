chai = require("chai")
expect = chai.expect
driverUtil = require('../../target/driverUtil')
data = require('../data')

describe "Utility", ->
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

    it "gets rid of empty ANDs", ->
      expect(driverUtil.simplifyFilter({
        type: 'and'
        filters: []
      })).to.deep.equal({
        type: 'true'
      })

    it "gets rid of single ANDs", ->
      expect(driverUtil.simplifyFilter({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of TRUEs in ANDs", ->
      expect(driverUtil.simplifyFilter({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'true'
          }
        ]
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of nested single and empty ANDs", ->
      expect(driverUtil.simplifyFilter({
        type: 'and'
        filters: [
          {
            type: 'and'
            filters: [
              {
                type: 'is'
                attribute: 'venue'
                value: 'Google'
              }
            ]
          }
          {
            type: 'and'
            filters: []
          }
        ]
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of empty IN", ->
      expect(driverUtil.simplifyFilter({
        type: 'in'
        values: []
      })).to.deep.equal({
        type: 'false'
      })

    it "gets rid of empty ORs", ->
      expect(driverUtil.simplifyFilter({
        type: 'or'
        filters: []
      })).to.deep.equal({
        type: 'false'
      })

    it "gets rid of single ORs", ->
      expect(driverUtil.simplifyFilter({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of nested single and empty ORs", ->
      expect(driverUtil.simplifyFilter({
        type: 'or'
        filters: [
          {
            type: 'or'
            filters: [
              {
                type: 'is'
                attribute: 'venue'
                value: 'Google'
              }
            ]
          }
          {
            type: 'or'
            filters: []
          }
        ]
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of NOT(TRUE)", ->
      expect(driverUtil.simplifyFilter({
        type: 'not'
        filter: {
          type: 'true'
        }
      })).to.deep.equal({
        type: 'false'
      })

    it "gets rid of NOT(FALSE)", ->
      expect(driverUtil.simplifyFilter({
        type: 'not'
        filter: {
          type: 'false'
        }
      })).to.deep.equal({
        type: 'true'
      })

    it "handles not()", ->
      expect(driverUtil.simplifyFilter({
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      })).to.deep.equal({
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      })

    it "gets rid of NOT(NOT(*))", ->
      expect(driverUtil.simplifyFilter({
        type: 'not'
        filter: {
          type: 'not'
          filter: {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        }
      })).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })


  describe "extractFilterByAttribute", ->
    it 'throws on bad input', ->
      expect(->
        driverUtil.extractFilterByAttribute(null, 'country')
      ).to.throw(TypeError)

      expect(->
        driverUtil.extractFilterByAttribute({ type: 'true' })
      ).to.throw(TypeError)

    it 'works on a single included filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      }, 'venue')).to.deep.equal([
        {
          type: 'true'
        }
        {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      ])

    it 'works on a single excluded filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      }, 'advertiser')).to.deep.equal([
        {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      ])

    it 'works on a small AND filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
        ]
      }, 'country')).to.deep.equal([
        {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
        {
          type: 'is'
          attribute: 'country'
          value: 'USA'
        }
      ])

    it 'works on an AND filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
        ]
      }, 'country')).to.deep.equal([
        {
          type: 'and'
          filters: [
            {
              type: 'is'
              attribute: 'state'
              value: 'California'
            }
            {
              type: 'is'
              attribute: 'venue'
              value: 'Google'
            }
          ]
        }
        {
          type: 'is'
          attribute: 'country'
          value: 'USA'
        }
      ])

    it 'extracts a NOT filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'not'
            filter: {
              type: 'is'
              attribute: 'country'
              value: 'USA'
            }
          }
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
        ]
      }, 'country')).to.deep.equal([
        {
          type: 'and'
          filters: [
            {
              type: 'is'
              attribute: 'state'
              value: 'California'
            }
            {
              type: 'is'
              attribute: 'venue'
              value: 'Google'
            }
          ]
        }
        {
          type: 'not'
          filter: {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
        }
      ])

    it 'works with a true filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'true'
      }, 'country')).to.deep.equal([
        { type: 'true' }
      ])

    it 'works with a false filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'false'
      }, 'country')).to.deep.equal([
        { type: 'false' }
      ])

    it 'does not work on OR filter', ->
      expect(driverUtil.extractFilterByAttribute({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'country'
            value: 'USA'
          }
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
        ]
      }, 'country')).to.deep.equal(null)


  describe 'filterToString', ->
    it 'needs a filter', ->
      expect(->
        driverUtil.filterToString(null)
      ).to.throw(TypeError)

    it 'properly translates empty filter', ->
      filter = { type: 'true' }
      expect(driverUtil.filterToString(filter)).to.equal('Everything')

    it 'properly translates false filter', ->
      filter = { type: 'false' }
      expect(driverUtil.filterToString(filter)).to.equal('Nothing')

    it 'properly translates is filter', ->
      filter = {
        type: 'is'
        attribute: 'Color'
        value: 'Red'
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color is Red')

    it 'properly translates in filter', ->
      filter = {
        type: 'in'
        attribute: 'Color'
        values: []
      }
      expect(driverUtil.filterToString(filter)).to.equal('Nothing')

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

    it 'properly translates fragements filter', ->
      filter = {
        type: 'fragments'
        attribute: 'Color'
        fragments: ['Red', 'Blue']
      }
      expect(driverUtil.filterToString(filter)).to.equal("Color contains 'Red', and 'Blue'")

    it 'properly translates match filter', ->
      filter = {
        type: 'match'
        attribute: 'Color'
        match: "^R"
      }
      expect(driverUtil.filterToString(filter)).to.equal('Color matches /^R/')

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

    it 'properly translates and filter', ->
      filter = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
        ]
      }
      expect(driverUtil.filterToString(filter)).to.equal("Color is Red")

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
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) and (Color is either Red or Blue)")

    it 'properly translates or filter', ->
      filter = {
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
        ]
      }
      expect(driverUtil.filterToString(filter)).to.equal("Color is Red")

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
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) or (Color is either Red or Blue)")

    it 'handles bad filter type', ->
      filter = {
        type: 'hello'
        attribute: 'Color'
        value: 'Red'
      }
      expect(->
        driverUtil.filterToString(filter)
      ).to.throw(TypeError, 'bad filter type')

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
      expect(driverUtil.filterToString(filter)).to.equal("not ((Color is Red) or (Color is either Red or Blue))")

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
      expect(driverUtil.filterToString(filter)).to.equal("(Color is Red) and (Color is either Red or Blue) and (not (Color is Red))")
