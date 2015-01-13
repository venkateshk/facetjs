{ expect } = require("chai")

{ FacetDataset, FacetFilter, FacetSplit, FacetApply, FacetCombine, SegmentTree } = require('../../build/query')

{ FacetVis } = require('../../build/render/facetVis')

{ Shape, RectangularShape } = require('../../build/render/shape')

#diamondsData = require('../../data/diamonds.js')
#simpleDiamonds = simpleDriver(diamondsData)

describe "Facet Vis", ->
  describe "#getQueryParts()", ->
    it "works for initial facet vis", ->
      facetVis = new FacetVis({})
        .def('diamonds', FacetDataset.BASE.and(FacetFilter.fromJS({ attribute: 'quality', type: 'is', value: 'high' })))
        .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
        .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))

      expect(facetVis.getQueryParts()).to.deep.equal([
        {
          "attribute": "quality"
          "operation": "filter"
          "type": "is"
          "value": "high"
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

  describe "#evaluate()", ->
    it "works for initial facet vis", ->
      facetVis = new FacetVis({})
        .def('diamonds', FacetDataset.BASE.and(FacetFilter.fromJS({ attribute: 'quality', type: 'is', value: 'high' })))
        .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
        .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
        .def('Five', 5)
        .def('Shape', Shape.rectangle(800, 600))

      segmentTree = SegmentTree.fromJS({
        prop: {
          "Count": 20
          "TotalPrice": 1337
        }
      })

      stat = facetVis.evaluate(segmentTree)
      expect(stat.toJS()).to.deep.equal({
        "Count": 20
        "TotalPrice": 1337
        "Five": 5
        "Shape": {
          "height": 600
          "width": 800
          "x": 0
          "y": 0
        }
      })

    it "works for a split", ->
      facetVis = new FacetVis({})
        .def('diamonds', FacetDataset.BASE.and(FacetFilter.fromJS({ attribute: 'quality', type: 'is', value: 'high' })))
        .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
        .def('TotalPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
        .def('Five', 5)
        .def('Shape', Shape.rectangle(800, 600))
        .def('Cuts',
          new FacetVis({
            split: FacetSplit.fromJS({
              bucket: 'identity',
              attribute: 'cut'
            })
            splitName: 'Cut'
          })
            .def('Count', FacetApply.fromJS({ aggregate: 'count' }))
            .def('CutPrice', FacetApply.fromJS({ aggregate: 'sum', attribute: 'price' }))
            .sort('Cut', 'descending')
            .limit(3)
            .def('myStage', (d) ->
              return d['Shape'].margin({
                bottom: 0,
                height: d.CutPrice
              })
            )
        )

      segmentTree = SegmentTree.fromJS({
        prop: {
          "Count": 20
          "TotalPrice": 1337
        }
        splits: [
          {
            prop: {
              "Cut": "Great"
              "Count": 10
              "CutPrice": 133
            }
          },
          {
            prop: {
              "Cut": "Amazing"
              "Count": 4
              "CutPrice": 337
            }
          },
          {
            prop: {
              "Cut": "Crappy"
              "Count": 2
              "CutPrice": 13
            }
          }
        ]
      })

      stat = facetVis.evaluate(segmentTree)
      expect(stat.toJS()).to.deep.equal({
        "Count": 20
        "Five": 5
        "Shape": {
          "height": 600
          "width": 800
          "x": 0
          "y": 0
        }
        "TotalPrice": 1337
        "Cuts": [
          {
            "Count": 10
            "Cut": "Great"
            "CutPrice": 133
            "myStage": {
              "height": 133
              "width": 800
              "x": 0
              "y": 467
            }
          }
          {
            "Count": 4
            "Cut": "Amazing"
            "CutPrice": 337
            "myStage": {
              "height": 337
              "width": 800
              "x": 0
              "y": 263
            }
          }
          {
            "Count": 2
            "Cut": "Crappy"
            "CutPrice": 13
            "myStage": {
              "height": 13
              "width": 800
              "x": 0
              "y": 587
            }
          }
        ]
      })

      # Check proto link
      expect(stat['Cuts'][0]['Five']).to.equal(5)
      expect(stat['Cuts'][1]['TotalPrice']).to.equal(1337)

