{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ FacetDataset } = require('../../build/query/dataset')

describe "FacetDataset", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetDataset, [
      {
        name: 'ideal-cut'
        source: 'base'
        filter: {
          type: 'is'
          attribute: 'cut'
          value: 'Ideal'
        }
      }
      {
        name: 'good-cut'
        source: 'base'
        filter: {
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
      }
      {
        name: 'good-cut'
        source: 'diamonds'
        filter: {
          type: 'is'
          attribute: 'cut'
          value: 'Good'
        }
      }
    ])
