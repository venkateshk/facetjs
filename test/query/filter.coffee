chai = require("chai")
expect = chai.expect

{
  FacetFilter
  TrueFilter
  FalseFilter
  IsFilter
  InFilter
  FragmentsFilter
  MatchFilter
  WithinFilter
  NotFilter
  AndFilter
  OrFilter
} = require('../../target/query')

describe "filter", ->

  describe 'toString', ->
    it 'properly describes empty filter', ->
      filterSpec = { type: 'true' }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Everything')

    it 'properly describes false filter', ->
      filterSpec = { type: 'false' }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Nothing')

    it 'properly describes is filter', ->
      filterSpec = {
        type: 'is'
        attribute: 'Color'
        value: 'Red'
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Color is Red')

    it 'properly describes in filter', ->
      filterSpec = {
        type: 'in'
        attribute: 'Color'
        values: []
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Nothing')

      filterSpec = {
        type: 'in'
        attribute: 'Color'
        values: ['Red']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Color is Red')

      filterSpec = {
        type: 'in'
        attribute: 'Color'
        values: ['Red', 'Blue']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Color is either Red or Blue')

      filterSpec = {
        type: 'in'
        attribute: 'Color'
        values: ['Red', 'Blue', 'Green']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Color is one of: Red, Blue, or Green')

    it 'properly describes fragements filter', ->
      filterSpec = {
        type: 'fragments'
        attribute: 'Color'
        fragments: ['Red', 'Blue']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("Color contains 'Red', and 'Blue'")

    it 'properly describes match filter', ->
      filterSpec = {
        type: 'match'
        attribute: 'Color'
        match: "^R"
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Color matches /^R/')

    it 'properly describes within filter', ->
      filterSpec = {
        type: 'within'
        attribute: 'Number'
        range: [1, 10]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Number is within 1 and 10')

      filterSpec = {
        type: 'within'
        attribute: 'Time'
        range: ["2013-07-09T20:30:40.251Z", "2014-07-09T20:30:40.251Z"]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("Time is within 2013-07-09T20:30:40.251Z and 2014-07-09T20:30:40.251Z")

    it 'properly describes not filter', ->
      filterSpec = {
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'Color'
          value: 'Red'
        }
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('not (Color is Red)')

    it 'properly describes and filter', ->
      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("Color is Red")

      filterSpec = {
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
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(Color is Red) and (Color is either Red or Blue)")

    it 'properly describes or filter', ->
      filterSpec = {
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'Color'
            value: 'Red'
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("Color is Red")

      filterSpec = {
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
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(Color is Red) or (Color is either Red or Blue)")

    it 'properly describes nested filter 1', ->
      filterSpec = {
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
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("not ((Color is Red) or (Color is either Red or Blue))")

    it 'properly describes nested filter 2', ->
      filterSpec = {
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
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(Color is Red) and (Color is either Red or Blue) and (not (Color is Red))")


  describe "simplify", ->
    it "it keeps regular filters unchanged", ->
      expect(FacetFilter.fromSpec({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      })

    it "flattens (and sorts) nested ANDs", ->
      expect(FacetFilter.fromSpec({
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
      }).simplify().valueOf()).to.deep.equal({
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
      expect(FacetFilter.fromSpec({
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
      }).simplify().valueOf()).to.deep.equal({
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
      expect(FacetFilter.fromSpec({
        type: 'and'
        filters: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'true'
      })

    it "gets rid of single ANDs", ->
      expect(FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of TRUEs in ANDs", ->
      expect(FacetFilter.fromSpec({
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
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of nested single and empty ANDs", ->
      expect(FacetFilter.fromSpec({
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
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of empty IN", ->
      expect(FacetFilter.fromSpec({
        type: 'in'
        attribute: 'venue'
        values: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of empty ORs", ->
      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of single ORs", ->
      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of nested single and empty ORs", ->
      expect(FacetFilter.fromSpec({
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
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "gets rid of NOT(TRUE)", ->
      expect(FacetFilter.fromSpec({
        type: 'not'
        filter: {
          type: 'true'
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of NOT(FALSE)", ->
      expect(FacetFilter.fromSpec({
        type: 'not'
        filter: {
          type: 'false'
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'true'
      })

    it "handles not()", ->
      expect(FacetFilter.fromSpec({
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'not'
        filter: {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      })

    it "gets rid of NOT(NOT(*))", ->
      expect(FacetFilter.fromSpec({
        type: 'not'
        filter: {
          type: 'not'
          filter: {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      })

    it "merges WITHIN filters in AND", ->
      expect(FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 40]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'within'
        attribute: 'age'
        range: [30, 40]
      })

      expect(FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 25]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'and'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 25]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      })

      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/05'), new Date('2013/01/10')]
          }
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/08'), new Date('2013/01/20')]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'within'
        attribute: 'time'
        range: [new Date('2013/01/05'), new Date('2013/01/20')]
      })

    it "merges WITHIN filters in OR", ->
      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 40]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'within'
        attribute: 'age'
        range: [20, 50]
      })

      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 30]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'within'
        attribute: 'age'
        range: [20, 50]
      })

      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'age'
            range: [20, 25]
          }
          {
            type: 'within'
            attribute: 'age'
            range: [30, 50]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })


  describe "extractFilterByAttribute", ->
    mapValueOf = (arr) ->
      return arr unless Array.isArray(arr)
      return arr.map((a) -> a.valueOf())

    it 'throws on bad input', ->
      expect(->
        new TrueFilter().extractFilterByAttribute()
      ).to.throw(TypeError)

    it 'works on a single included filter', ->
      expect(mapValueOf(FacetFilter.fromSpec({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      }).extractFilterByAttribute('venue'))).to.deep.equal([
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
      expect(mapValueOf(FacetFilter.fromSpec({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      }).extractFilterByAttribute('advertiser'))).to.deep.equal([
        {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
      ])

    it 'works on a small AND filter', ->
      expect(mapValueOf(FacetFilter.fromSpec({
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
      }).extractFilterByAttribute('country'))).to.deep.equal([
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
      expect(mapValueOf(FacetFilter.fromSpec({
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
      }).extractFilterByAttribute('country'))).to.deep.equal([
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
      expect(mapValueOf(FacetFilter.fromSpec({
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
      }).extractFilterByAttribute('country'))).to.deep.equal([
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
      expect(mapValueOf(FacetFilter.fromSpec({
        type: 'true'
      }).extractFilterByAttribute('country'))).to.deep.equal([
        { type: 'true' }
      ])

    it 'works with a false filter', ->
      expect(mapValueOf(FacetFilter.fromSpec({
        type: 'false'
      }).extractFilterByAttribute('country'))).to.deep.equal([
        { type: 'false' }
      ])

    it 'does not work on OR filter', ->
      # last
      expect(mapValueOf(FacetFilter.fromSpec({
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
      }).extractFilterByAttribute('country'))).to.deep.equal(null)









