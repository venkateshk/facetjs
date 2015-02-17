{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require("../../../build/facet")
{ FacetDataset } = facet.legacy

describe "FacetDataset", ->
  it "passes higher object tests", ->
    testHigherObjects(FacetDataset, [
      {
        name: 'basic-dataset'
        source: 'base'
      }
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
