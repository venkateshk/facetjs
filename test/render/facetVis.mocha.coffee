{ expect } = require("chai")

{ FacetSplit, FacetApply, FacetCombine } = require('../../build/query')

{ FacetVis } = require('../../build/render/facetVis')

describe "Facet Vis", ->
  describe "#getQueryParts()", ->
    it "works for single initial split", ->
      facetVis = new FacetVis({})
        .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
        .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
        .sort('Cut', 'descending')
        .limit(10)

      expect(facetVis.getQueryParts()).to.deep.equal([
        {
          "aggregate": "count"
          "operation": "apply"
          "name": 'Count'
        }
        {
          "aggregate": "sum"
          "attribute": "price"
          "operation": "apply"
          "name": 'TotalPrice'
        }
      ])

    it "works for single mid split", ->
      facetVis = new FacetVis({
        split: FacetSplit.fromJS({
          bucket: 'identity',
          attribute: 'cut'
        })
        splitName: 'Cut'
      })
        .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
        .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
        .sort('Cut', 'descending')
        .limit(10)

      expect(facetVis.getQueryParts()).to.deep.equal([
        {
          "attribute": "cut"
          "bucket": "identity"
          "name": "Cut"
          "operation": "split"
        }
        {
          "aggregate": "count"
          "operation": "apply"
          "name": 'Count'
        }
        {
          "aggregate": "sum"
          "attribute": "price"
          "operation": "apply"
          "name": 'TotalPrice'
        }
        {
          "method": "slice"
          "operation": "combine"
          "limit": 10
          "sort": {
            "compare": "natural"
            "direction": "descending"
            "prop": "Cut"
          }
        }
      ])

    it "works for multi split", ->
      facetVis = new FacetVis({
        split: FacetSplit.fromJS({
          bucket: 'identity',
          attribute: 'cut'
        })
        splitName: 'Cut'
      })
      .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
      .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
      .sort('Cut', 'descending')
      .limit(10)
      .def('Colors',
        new FacetVis({
          split: FacetSplit.fromJS({
            bucket: 'identity',
            attribute: 'color'
          })
          splitName: 'Color'
        })
          .def('ColCount', FacetApply.fromJS({ aggregate: 'count' }))
          .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
          .sort('Cut', 'ascending')
          .limit(7)
      )

      expect(facetVis.getQueryParts()).to.deep.equal([
        {
          "attribute": "cut"
          "bucket": "identity"
          "name": "Cut"
          "operation": "split"
        }
        {
          "aggregate": "count"
          "name": "Count"
          "operation": "apply"
        }
        {
          "aggregate": "sum"
          "attribute": "price"
          "name": "TotalPrice"
          "operation": "apply"
        }
        {
          "method": "slice"
          "operation": "combine"
          "limit": 10
          "sort": {
            "compare": "natural"
            "direction": "descending"
            "prop": "Cut"
          }
        }
        {
          "attribute": "color"
          "bucket": "identity"
          "name": "Color"
          "operation": "split"
        }
        {
          "aggregate": "count"
          "name": "ColCount"
          "operation": "apply"
        }
        {
          "aggregate": "sum"
          "attribute": "price"
          "name": "TotalPrice"
          "operation": "apply"
        }
        {
          "method": "slice"
          "operation": "combine"
          "limit": 7
          "sort": {
            "compare": "natural"
            "direction": "ascending"
            "prop": "Cut"
          }
        }
      ])
