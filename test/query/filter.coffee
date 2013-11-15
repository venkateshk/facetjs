chai = require("chai")
expect = chai.expect

{FacetFilter} = require('../../build/query')

describe "FacetFilter", ->
  describe "errors", ->
    it "missing type", ->
      filterSpec = {}
      expect(-> FacetFilter.fromSpec(filterSpec)).to.throw(Error, "type must be defined")

    it "invalid type in filter", ->
      filterSpec = { type: ['wtf?'] }
      expect(-> FacetFilter.fromSpec(filterSpec)).to.throw(Error, "type must be a string")

    it "unknown type in filter", ->
      filterSpec = { type: 'poo' }
      expect(-> FacetFilter.fromSpec(filterSpec)).to.throw(Error, "unsupported filter type 'poo'")


  describe "preserves", ->
    it "is", ->
      filterSpec = {
        type: 'is'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromSpec(filterSpec).valueOf()).to.deep.equal(filterSpec)

    it "contains", ->
      filterSpec = {
        type: 'contains'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromSpec(filterSpec).valueOf()).to.deep.equal(filterSpec)

    it "match", ->
      filterSpec = {
        type: 'match'
        attribute: 'country'
        expression: 'U[SK]'
      }
      expect(FacetFilter.fromSpec(filterSpec).valueOf()).to.deep.equal(filterSpec)


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
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('color is Red')

    it 'properly describes in filter', ->
      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: []
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('Nothing')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('color is Red')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red', 'Blue']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('color is either Red or Blue')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red', 'Blue', 'Green']
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('color is one of: Red, Blue, or Green')

    it 'properly describes contains filter', ->
      filterSpec = {
        type: 'contains'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("color contains 'Red'")

    it 'properly describes match filter', ->
      filterSpec = {
        type: 'match'
        attribute: 'color'
        expression: "^R"
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('color matches /^R/')

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
          attribute: 'color'
          value: 'Red'
        }
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal('not (color is Red)')

    it 'properly describes and filter', ->
      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("color is Red")

      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'color'
            values: ['Red', 'Blue']
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(color is Red) and (color is either Red or Blue)")

    it 'properly describes or filter', ->
      filterSpec = {
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("color is Red")

      filterSpec = {
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'color'
            values: ['Red', 'Blue']
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(color is Red) or (color is either Red or Blue)")

    it 'properly describes nested filter 1', ->
      filterSpec = {
        type: 'not'
        filter: {
          type: 'or'
          filters: [
            {
              type: 'is'
              attribute: 'color'
              value: 'Red'
            }
            {
              type: 'in'
              attribute: 'color'
              values: ['Red', 'Blue']
            }
          ]
        }
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("not ((color is Red) or (color is either Red or Blue))")

    it 'properly describes nested filter 2', ->
      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
          {
            type: 'in'
            attribute: 'color'
            values: ['Red', 'Blue']
          }
          {
            type: 'not'
            filter: {
              type: 'is'
              attribute: 'color'
              value: 'Red'
            }
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).toString())
        .to.equal("(color is Red) and (color is either Red or Blue) and (not (color is Red))")


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

    it "gets rid of repeating filters in ANDs", ->
      expect(FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
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

    it "gets rid of repeating filters in ORs", ->
      expect(FacetFilter.fromSpec({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
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
        FacetFilter.fromSpec({
          type: 'true'
        }).extractFilterByAttribute()
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


  describe "isEqual", ->
    it "works for all filters", ->
      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Google', 'LinkedIn']
          }
          {
            type: 'contains'
            attribute: 'page'
            value: 'face'
          }
          {
            type: 'match'
            attribute: 'size'
            expression: "\d+x\d+"
          }
          {
            type: 'within'
            attribute: 'age'
            range: [10, 50]
          }
          {
            type: 'not'
            filter: {
              type: 'or'
              filters: [
                {
                  type: 'is'
                  attribute: 'shoe_size'
                  value: '13'
                }
                {
                  type: 'in'
                  attribute: 'train'
                  values: ['TGV', 'BTS']
                }
              ]
            }
          }
        ]
      }
      filter1 = FacetFilter.fromSpec(filterSpec)
      filter2 = FacetFilter.fromSpec(filterSpec)
      filterSpec.filters[0].value = 'Nevada'
      filter3 = FacetFilter.fromSpec(filterSpec)
      expect(filter1.isEqual(filter2)).to.equal(true)
      expect(filter1.isEqual(filter3)).to.equal(false)


  describe "getComplexity", ->
    it "works for complex filter", ->
      filterSpec = {
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Google', 'LinkedIn']
          }
          {
            type: 'contains'
            attribute: 'page'
            value: 'face'
          }
          {
            type: 'match'
            attribute: 'size'
            expression: "\d+x\d+"
          }
          {
            type: 'within'
            attribute: 'age'
            range: [10, 50]
          }
          {
            type: 'not'
            filter: {
              type: 'or'
              filters: [
                {
                  type: 'is'
                  attribute: 'shoe_size'
                  value: '13'
                }
                {
                  type: 'in'
                  attribute: 'train'
                  values: ['TGV', 'BTS']
                }
              ]
            }
          }
        ]
      }
      expect(FacetFilter.fromSpec(filterSpec).getComplexity()).to.equal(10)


  describe "getFilterFn", ->
    it "works for IS filter", ->
      filterSpec = {
        type: 'is'
        attribute: 'state'
        value: 'California'
      }
      filterFn = FacetFilter.fromSpec(filterSpec).getFilterFn()
      expect(filterFn({ state: 'California' })).to.equal(true)
      expect(filterFn({ state: 'Nevada' })).to.equal(false)


  describe "FacetFilter.filterDiff", ->
    it "computes a subset with IN filters", ->
      sup = FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'state'
            value: 'California'
          }
          {
            type: 'is'
            attribute: 'color'
            value: 'Red'
          }
        ]
      })
      sub = FacetFilter.fromSpec({
        type: 'is'
        attribute: 'color'
        value: 'Red'
      })

      diff = FacetFilter.filterDiff(sup, sub)
      expect(diff).to.be.an('array').and.to.have.length(1)
      expect(diff[0].valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'state'
        value: 'California'
      })

      diff = FacetFilter.filterDiff(sub, sup)
      expect(diff).to.be.null

    it "computes a subset with CONTAINS filters", ->
      sup = FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'contains'
            attribute: 'page'
            value: 'California'
          }
          {
            type: 'not'
            filter: {
              type: 'contains'
              attribute: 'page'
              value: 'Moon'
            }
          }
          {
            type: 'contains'
            attribute: 'page'
            value: 'Google'
          }
        ]
      })
      sub = FacetFilter.fromSpec({
        type: 'and'
        filters: [
          {
            type: 'contains'
            attribute: 'page'
            value: 'California'
          }
          {
            type: 'not'
            filter: {
              type: 'contains'
              attribute: 'page'
              value: 'Moon'
            }
          }
        ]
      })

      diff = FacetFilter.filterDiff(sup, sub)
      expect(diff).to.be.an('array').and.to.have.length(1)
      expect(diff[0].valueOf()).to.deep.equal({
        type: 'contains'
        attribute: 'page'
        value: 'Google'
      })
      return















