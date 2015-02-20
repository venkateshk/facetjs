{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Dataset } = facet.core

describe "Dataset", ->
  it "passes higher object tests", ->
    testHigherObjects(Dataset, [
      [
        { x: 1, y: 2 }
        { x: 2, y: 3 }
      ]

      [
        {
          Void: null
          SoTrue: true
          NotSoTrue: false
          Count: 2353
          HowAwesome: { type: 'NUMBER', value: 'Infinity' }
          HowLame: { type: 'NUMBER', value: '-Infinity' }
          HowMuch: {
            type: 'NUMBER_RANGE'
            start: 0
            end: 7
          }
          ToInfinityAndBeyond: {
            type: 'NUMBER_RANGE'
            start: '-Infinity'
            end: 'Infinity'
          }
          SomeDate: {
            type: 'DATE'
            value: new Date('2015-01-26T04:54:10Z')
          }
          SomeTimeRange: {
            type: 'TIME_RANGE'
            start: new Date('2015-01-26T04:54:10Z')
            end:   new Date('2015-01-26T05:00:00Z')
          }
          SubData: [
            { x: 1, y: 2 }
            { x: 2, y: 3 }
          ]
        }
      ]

      [
        {
          "Carat": {
            "end": 0.5
            "start": 0.25
            "type": "NUMBER_RANGE"
          }
          "Count": 1360
        }
        {
          "Carat": {
            "end": 0.75
            "start": 0.5
            "type": "NUMBER_RANGE"
          }
          "Count": 919
        }
        {
          "Carat": {
            "end": 1.25
            "start": 1
            "type": "NUMBER_RANGE"
          }
          "Count": 298
        }
      ]
    ], {
      newThrows: true
    })
