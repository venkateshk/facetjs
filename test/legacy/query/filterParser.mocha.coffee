{ expect } = require("chai")
{ parse } = require('../../build/parser/filter')

describe "parser", ->
  describe "Errors", ->
    it "should error on unclosed quotes", ->
      qry = "country is \"france or (color is yellow and color is red or color is purple"
      expect(-> parse(qry)).to.throw(Error, "Expected Value but \"\\\"\" found.")

    it "should error on unclosed parentheses", ->
      qry = "country is france or (color is yellow and color is red or color is purple"
      expect(-> parse(qry)).to.throw(Error, "Expected \")\", \"and\" or \"or\" but end of input found.")

    it "should error on malformed input", ->
      qry = "country is france color is yellow and color is red or color is purple"
      expect(-> parse(qry)).to.throw(Error, "Expected \"and\", \"or\" or end of input but \"c\" found.")
      qry = "country is color is yellow and color is red or color is purple"
      expect(-> parse(qry)).to.throw(Error, "Expected \"and\", \"or\" or end of input but \"i\" found.")


  describe "Successful parsing", ->
    it "can deal with a combination of ands and ors correctly - case: 1", ->
      qry = "country is france or color is yellow and color is red or color is purple"
      expect(parse(qry)).to.deep.equal({
        "type": "and"
        "filters": [
          {
            "type": "or"
            "filters": [
              {
                "type": "is",
                "value": "france",
                "attribute": "country"
              },
              {
                "type": "is",
                "value": "yellow",
                "attribute": "color"
              }
            ]
          },
          {
            "type": "or"
            "filters": [
              {
                "type": "is",
                "value": "red",
                "attribute": "color"
              },
              {
                "type": "is",
                "value": "purple",
                "attribute": "color"
              }
            ]
          }
        ]
      })

    it "can deal with ins", ->
      qry = "country is france or user in (france, china, japan, russia)"
      expect(parse(qry)).to.deep.equal({
        "type": "or"
        "filters": [
          {
            "type": "is",
            "value": "france",
            "attribute": "country"
            },
            {
              "type": "in"
              "attribute": "user"
              "values": ["france", "china", "japan", "russia"],
            }
          ]
          })

    it "can deal with a combination of ands and ors correctly - case: 2", ->
      qry = "country is france and color is yellow or color is red and color is purple"
      expect(parse(qry)).to.deep.equal({
        "type": "and"
        "filters": [
          {
              "type": "is",
              "value": "france",
              "attribute": "country"
          },
          {
           "type": "or"
           "filters": [
              {
                "type": "is",
                "value": "yellow",
                "attribute": "color"
              },
              {
                "type": "is",
                "value": "red",
                "attribute": "color"
              }
            ]
          },
          {
            "type": "is",
            "value": "purple",
            "attribute": "color"
          }
        ]
      })

    it "can deal with nots correctly", ->
      qry = "country is france or not color is yellow and not color is red or color is purple"
      expect(parse(qry)).to.deep.equal({
       "type": "and",
       "filters": [
          {
             "type": "or",
             "filters": [
                {
                   "type": "is",
                   "value": "france",
                   "attribute": "country"
                },
                {
                   "type": "not",
                   "filter": {
                      "type": "is",
                      "value": "yellow",
                      "attribute": "color"
                   }
                }
             ]
          },
          {
             "type": "or",
             "filters": [
                {
                   "type": "not",
                   "filter": {
                      "type": "is",
                      "value": "red",
                      "attribute": "color"
                   }
                },
                {
                   "type": "is",
                   "value": "purple",
                   "attribute": "color"
                }
             ]
          }
       ]
    })

    it "can deal with parentheses correctly", ->
      qry = "country is france or (color is yellow and color is red) or color is purple"
      expect(parse(qry)).to.deep.equal({
        "type": "or",
        "filters": [
          {
            "type": "is",
            "value": "france",
            "attribute": "country"
          },
          {
            "type": "and",
            "filters": [
                {
                  "type": "is",
                  "value": "yellow",
                  "attribute": "color"
                },
                {
                  "type": "is",
                  "value": "red",
                  "attribute": "color"
                }
             ]
          },
          {
            "type": "is",
            "value": "purple",
            "attribute": "color"
          }
        ]
      })

    it "can deal with not combined with parentheses correctly", ->
      qry = "not(country is france or not (color is yellow and color is red)) or color is purple"
      expect(parse(qry)).to.deep.equal({
         "type": "or",
         "filters": [
            {
               "type": "not",
               "filter": {
                  "type": "or",
                  "filters": [
                     {
                        "type": "is",
                        "value": "france",
                        "attribute": "country"
                     },
                     {
                        "type": "not",
                        "filter": {
                           "type": "and",
                           "filters": [
                              {
                                 "type": "is",
                                 "value": "yellow",
                                 "attribute": "color"
                              },
                              {
                                 "type": "is",
                                 "value": "red",
                                 "attribute": "color"
                              }
                           ]
                        }
                     }
                  ]
               }
            },
            {
               "type": "is",
               "value": "purple",
               "attribute": "color"
            }
         ]
      })

    it "should accept anything within quotation marks (block escape) for a value", ->
      qry = "country is \"france or (color is yellow and color is red)\" or color is purple"
      expect(parse(qry)).to.deep.equal({
        "type": "or",
        "filters": [
         {
          "type": "is",
          "value": "france or (color is yellow and color is red)",
          "attribute": "country"
          },
          {
            "type": "is",
            "value": "purple",
            "attribute": "color"
          }
        ]
        })

    it "should accept anything within tick marks (block escape) for an attribute", ->
      qry = "`country is france or (color is yellow and color is red) or color` is purple"
      expect(parse(qry)).to.deep.equal({
          "type": "is",
          "value": "purple",
          "attribute": "country is france or (color is yellow and color is red) or color"
        })
