{expect} = require("chai")

{FacetFilter} = require('../../src/query')

describe "FacetFilter", ->
  describe "errors", ->
    it "missing type", ->
      filterSpec = {}
      expect(-> FacetFilter.fromJS(filterSpec)).to.throw(Error, "type must be defined")

    it "invalid type in filter", ->
      filterSpec = { type: ['wtf?'] }
      expect(-> FacetFilter.fromJS(filterSpec)).to.throw(Error, "type must be a string")

    it "unknown type in filter", ->
      filterSpec = { type: 'poo' }
      expect(-> FacetFilter.fromJS(filterSpec)).to.throw(Error, "unsupported filter type 'poo'")


  describe "preserves", ->
    it "is", ->
      filterSpec = {
        type: 'is'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromJS(filterSpec).valueOf()).to.deep.equal(filterSpec)

    it "contains", ->
      filterSpec = {
        type: 'contains'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromJS(filterSpec).valueOf()).to.deep.equal(filterSpec)

    it "match", ->
      filterSpec = {
        type: 'match'
        attribute: 'country'
        expression: 'U[SK]'
      }
      expect(FacetFilter.fromJS(filterSpec).valueOf()).to.deep.equal(filterSpec)


  describe 'toString', ->
    it 'properly describes empty filter', ->
      filterSpec = { type: 'true' }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('None')

    it 'properly describes false filter', ->
      filterSpec = { type: 'false' }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('Nothing')

    it 'properly describes is filter', ->
      filterSpec = {
        type: 'is'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('color is Red')

    it 'properly describes in filter', ->
      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: []
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('Nothing')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red']
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('color is Red')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red', 'Blue']
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('color is either Red or Blue')

      filterSpec = {
        type: 'in'
        attribute: 'color'
        values: ['Red', 'Blue', 'Green']
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('color is one of: Red, Blue, or Green')

    it 'properly describes contains filter', ->
      filterSpec = {
        type: 'contains'
        attribute: 'color'
        value: 'Red'
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal("color contains 'Red'")

    it 'properly describes match filter', ->
      filterSpec = {
        type: 'match'
        attribute: 'color'
        expression: "^R"
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('color matches /^R/')

    it 'properly describes within filter', ->
      filterSpec = {
        type: 'within'
        attribute: 'Number'
        range: [1, 10]
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal('Number is within 1 and 10')

      filterSpec = {
        type: 'within'
        attribute: 'Time'
        range: ["2013-07-09T20:30:40.251Z", "2014-07-09T20:30:40.251Z"]
      }
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
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
      expect(FacetFilter.fromJS(filterSpec).toString())
        .to.equal("(color is Red) and (color is either Red or Blue) and (not (color is Red))")


  describe "simplify", ->
    it "keeps regular filters unchanged", ->
      expect(FacetFilter.fromJS({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'lady'
        value: 'GaGa'
      })

    it "turns IN filter into IS filter when appropriate", ->
      expect(FacetFilter.fromJS({
        type: 'in'
        attribute: 'device'
        values: ['Nexus 5', 'Nexus 5', 'Nexus 5']
      }).simplify().valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'device'
        value: 'Nexus 5'
      })

    it "sorts IN filters and removes duplicate values", ->
      expect(FacetFilter.fromJS({
        type: 'in'
        attribute: 'device'
        values: ['Nexus 5', 'Nexus 5', 'iPhone 5', 'Galaxy Note', 'Nexus 5']
      }).simplify().valueOf()).to.deep.equal({
        type: 'in'
        attribute: 'device'
        values: ['Galaxy Note', 'Nexus 5', 'iPhone 5']
      })

    it "flattens (and sorts) nested ANDs", ->
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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

    it "AND turns same attributed IS and IN filters into INs", ->
      expect(FacetFilter.fromJS({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Microsoft'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Microsoft', 'Yelp']
          }
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Microsoft'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['LinkedIn', 'Facebook', 'Microsoft']
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Microsoft'
          }
        ]
      })

    it "OR turns same attributed IS and IN filters into INs", ->
      expect(FacetFilter.fromJS({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Microsoft', 'Yelp']
          }
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'GitHub'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['LinkedIn', 'Facebook']
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Facebook', 'GitHub', 'Google', 'LinkedIn', 'Microsoft', 'Yelp']
          }
        ]
      })

    it "AND detects a complex FALSE", ->
      expect(FacetFilter.fromJS({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Microsoft'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['Microsoft', 'Yelp']
          }
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
          {
            type: 'is'
            attribute: 'venue'
            value: 'Microsoft'
          }
          {
            type: 'in'
            attribute: 'venue'
            values: ['LinkedIn', 'Facebook']
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of empty ANDs", ->
      expect(FacetFilter.fromJS({
        type: 'and'
        filters: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'true'
      })

    it "gets rid of single ANDs", ->
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
        type: 'in'
        attribute: 'venue'
        values: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of empty ORs", ->
      expect(FacetFilter.fromJS({
        type: 'or'
        filters: []
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of single ORs", ->
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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
      expect(FacetFilter.fromJS({
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

    it "preserves simple not()", ->
      expect(FacetFilter.fromJS({
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

    it "gets rid of NOT(TRUE)", ->
      expect(FacetFilter.fromJS({
        type: 'not'
        filter: {
          type: 'true'
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "gets rid of NOT(FALSE)", ->
      expect(FacetFilter.fromJS({
        type: 'not'
        filter: {
          type: 'false'
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'true'
      })

    it "gets rid of NOT(NOT(*))", ->
      expect(FacetFilter.fromJS({
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

    it "gets rid of NOT(AND(*)) with De Morgan", ->
      expect(FacetFilter.fromJS({
        type: 'not'
        filter: {
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
                attribute: 'device'
                value: 'Nexus 5'
              }
            }
          ]
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'or'
        filters: [
          {
            type: 'is'
            attribute: 'device'
            value: 'Nexus 5'
          }
          {
            type: 'not'
            filter: {
              type: 'is'
              attribute: 'venue'
              value: 'Google'
            }
          }
        ]
      })

    it "gets rid of NOT(OR(*)) with De Morgan", ->
      expect(FacetFilter.fromJS({
        type: 'not'
        filter: {
          type: 'or'
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
                attribute: 'device'
                value: 'Nexus 5'
              }
            }
          ]
        }
      }).simplify().valueOf()).to.deep.equal({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'device'
            value: 'Nexus 5'
          }
          {
            type: 'not'
            filter: {
              type: 'is'
              attribute: 'venue'
              value: 'Google'
            }
          }
        ]
      })

    it "merges WITHIN filters in AND", ->
      expect(FacetFilter.fromJS({
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

      expect(FacetFilter.fromJS({
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
        type: 'false'
      })

      expect(FacetFilter.fromJS({
        type: 'and'
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
        range: [new Date('2013/01/08'), new Date('2013/01/10')]
      })

      expect(FacetFilter.fromJS({
        type: 'and'
        filters: [
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/05'), new Date('2013/01/08')]
          }
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/10'), new Date('2013/01/20')]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'false'
      })

    it "merges WITHIN filters in OR", ->
      expect(FacetFilter.fromJS({
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

      expect(FacetFilter.fromJS({
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

      expect(FacetFilter.fromJS({
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
      })

      expect(FacetFilter.fromJS({
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

      expect(FacetFilter.fromJS({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/05'), new Date('2013/01/08')]
          }
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/10'), new Date('2013/01/20')]
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'or'
        filters: [
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/05'), new Date('2013/01/08')]
          }
          {
            type: 'within'
            attribute: 'time'
            range: [new Date('2013/01/10'), new Date('2013/01/20')]
          }
        ]
      })

    it "stops merging successfully for complicated filters", ->
      expect(FacetFilter.fromJS({
        type: 'and'
        filters: [
          {
            filter: {
              attribute: 'blocked_types'
              value: 'JavaScript Ad'
              type: 'is'
            }
            type: 'not'
          }
          {
            filter: {
              attribute: 'category_name'
              value: 'Restricted'
              type: 'is'
            }
            type: 'not'
          }
        ]
      }).simplify().valueOf()).to.deep.equal({
        type: 'and'
        filters: [
          {
            filter: {
              attribute: 'blocked_types'
              value: 'JavaScript Ad'
              type: 'is'
            }
            type: 'not'
          }
          {
            filter: {
              attribute: 'category_name'
              value: 'Restricted'
              type: 'is'
            }
            type: 'not'
          }
        ]
      })

    it "knows when something is simple", ->
      filter = FacetFilter.fromJS({
        type: 'and'
        filters: [
          {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
          {
            type: 'is'
            attribute: 'robot'
            value: 'Yes'
          }
        ]
      })
      simpleFilter = filter.simplify()
      expect(filter).to.not.equal(simpleFilter)
      simpleSimpleFilter = simpleFilter.simplify()
      expect(simpleFilter).to.equal(simpleSimpleFilter)


  describe "extractFilterByAttribute", ->
    mapValueOf = (arr) ->
      return arr unless Array.isArray(arr)
      return arr.map((a) -> a.valueOf())

    it 'throws on bad input', ->
      expect(->
        FacetFilter.fromJS({
          type: 'true'
        }).extractFilterByAttribute()
      ).to.throw(TypeError)

    it 'works on a single included filter', ->
      expect(mapValueOf(FacetFilter.fromJS({
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
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'is'
        attribute: 'venue'
        value: 'Google'
      }).extractFilterByAttribute('advertiser'))).to.deep.equal([
        {
          type: 'is'
          attribute: 'venue'
          value: 'Google'
        }
        {
          type: 'true'
        }
      ])

    it 'works on a small AND filter', ->
      expect(mapValueOf(FacetFilter.fromJS({
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
      expect(mapValueOf(FacetFilter.fromJS({
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
      expect(mapValueOf(FacetFilter.fromJS({
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
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'true'
      }).extractFilterByAttribute('country'))).to.deep.equal([
        { type: 'true' }
        { type: 'true' }
      ])

    it 'works with a false filter', ->
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'false'
      }).extractFilterByAttribute('country'))).to.deep.equal([
        { type: 'false' }
        { type: 'true' }
      ])

    it 'does not work on mixed OR filter', ->
      expect(mapValueOf(FacetFilter.fromJS({
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

    it 'works on mixed OR filter (all in)', ->
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'or'
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
              attribute: 'venue'
              value: 'Apple'
            }
          }
          {
            type: 'contains'
            attribute: 'venue'
            value: 'Moon'
          }
        ]
      }).extractFilterByAttribute('venue'))).to.deep.equal([
        { type: 'true' }
        {
          type: 'or'
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
                attribute: 'venue'
                value: 'Apple'
              }
            }
            {
              type: 'contains'
              attribute: 'venue'
              value: 'Moon'
            }
          ]
        }
      ])

    it 'works on mixed OR filter (all out)', ->
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'or'
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
              attribute: 'venue'
              value: 'Apple'
            }
          }
          {
            type: 'contains'
            attribute: 'venue'
            value: 'Moon'
          }
        ]
      }).extractFilterByAttribute('country'))).to.deep.equal([
        {
          type: 'or'
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
                attribute: 'venue'
                value: 'Apple'
              }
            }
            {
              type: 'contains'
              attribute: 'venue'
              value: 'Moon'
            }
          ]
        }
        { type: 'true' }
      ])

    it 'works on NOT filter', ->
      expect(mapValueOf(FacetFilter.fromJS({
        type: 'not'
        filter: {
          type: 'or'
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
                attribute: 'brand'
                value: 'Apple'
              }
            }
          ]
        }
      }).extractFilterByAttribute('venue'))).to.deep.equal([
        {
          type: 'is'
          attribute: 'brand'
          value: 'Apple'
        }
        {
          type: 'not'
          filter: {
            type: 'is'
            attribute: 'venue'
            value: 'Google'
          }
        }
      ])


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
            type: 'within'
            attribute: 'time'
            range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
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
      filter1 = FacetFilter.fromJS(filterSpec)
      filter2 = FacetFilter.fromJS(filterSpec)
      filterSpec.filters[0].value = 'Nevada'
      filter3 = FacetFilter.fromJS(filterSpec)
      expect(filter1.isEqual(filter2)).to.equal(true)
      expect(filter1.isEqual(filter3)).to.equal(false)

    it "works for dates", ->
      filter1 = FacetFilter.fromJS({
        type: 'within'
        attribute: 'time'
        range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
      })
      filter2 = FacetFilter.fromJS({
        type: 'within'
        attribute: 'time'
        range: [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
      })
      expect(filter1.isEqual(filter2)).to.equal(true)


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
      expect(FacetFilter.fromJS(filterSpec).getComplexity()).to.equal(10)


  describe "getFilterFn", ->
    it "works for IS filter", ->
      filterSpec = {
        type: 'is'
        attribute: 'state'
        value: 'California'
      }
      filterFn = FacetFilter.fromJS(filterSpec).getFilterFn()
      expect(filterFn({ state: 'California' })).to.equal(true)
      expect(filterFn({ state: 'Nevada' })).to.equal(false)


  describe "FacetFilter.filterDiff", ->
    it "computes a subset with IN filters", ->
      subFilter = FacetFilter.fromJS({
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
      superFilter = FacetFilter.fromJS({
        type: 'is'
        attribute: 'color'
        value: 'Red'
      })

      diff = FacetFilter.filterDiff(subFilter, superFilter)
      expect(diff).to.be.an('array').and.to.have.length(1)
      expect(diff[0].valueOf()).to.deep.equal({
        type: 'is'
        attribute: 'state'
        value: 'California'
      })

      diff = FacetFilter.filterDiff(superFilter, subFilter)
      expect(diff).to.be.null

    it "computes a subset with CONTAINS filters", ->
      subFilter = FacetFilter.fromJS({
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
      superFilter = FacetFilter.fromJS({
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

      diff = FacetFilter.filterDiff(subFilter, superFilter)
      expect(diff).to.be.an('array').and.to.have.length(1)
      expect(diff[0].valueOf()).to.deep.equal({
        type: 'contains'
        attribute: 'page'
        value: 'Google'
      })
      return
