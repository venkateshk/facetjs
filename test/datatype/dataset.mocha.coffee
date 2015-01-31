{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Dataset } = require('../../build/datatype/dataset')
{ TimeRange } = require('../../build/datatype/timeRange')

describe "Dataset", ->
  it "passes higher object tests", ->
    testHigherObjects(Dataset, [
      {
        dataset: 'base'
        data: [
          { x: 1, y: 2 }
          { x: 2, y: 3 }
        ]
      }
      {
        dataset: 'base'
        data: [
          {
            Void: null
            SoTrue: true
            NotSoTrue: false
            Count: 2353
            HowAwesome: { cat: 'NUMBER', value: 'Infinity' }
            HowLame: { cat: 'NUMBER', value: '-Infinity' }
            SomeTime: {
              cat: 'TIME_RANGE'
              start: new Date('2015-01-26T04:54:10Z')
              end:   new Date('2015-01-26T05:00:00Z')
            }
          }
        ]
      }
    ], {
      newThrows: true
    })
