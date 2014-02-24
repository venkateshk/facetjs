{ expect } = require("chai")

SegmentTree = require('../../src/driver/segmentTree')


describe "SegmentTree", ->
  it "preserves", ->
    segmentTreeSpec = {
      "prop": {},
      "splits": [
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 21551
          },
          "splits": [
            {
              "prop": {
                "Clarity": "VS2",
                "Count": 5071
              }
            },
            {
              "prop": {
                "Clarity": "SI1",
                "Count": 4282
              }
            }
          ]
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 13791
          }
        }
      ]
    }
    segmentTree = new SegmentTree(segmentTreeSpec)
    expect(segmentTree.valueOf()).to.deep.equal(segmentTreeSpec)
    expect(segmentTreeSpec.prop).to.equal(segmentTree.prop)
    expect(segmentTreeSpec.splits[0].prop).to.equal(segmentTree.splits[0].prop)

  it "sets parents correctly", ->
    segmentTreeSpec = {
      "prop": {},
      "splits": [
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 21551
          },
          "splits": [
            {
              "prop": {
                "Clarity": "VS2",
                "Count": 5071
              }
            },
            {
              "prop": {
                "Clarity": "SI1",
                "Count": 4282
              }
            }
          ]
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 13791
          }
        }
      ]
    }
    segmentTree = new SegmentTree(segmentTreeSpec)
    expect(segmentTree.parent).to.equal(null)
    expect(segmentTree.splits[0].parent).to.equal(segmentTree)
    expect(segmentTree.splits[0].splits[0].parent).to.equal(segmentTree.splits[0])

  it "cleans props", ->
    segmentTreeSpec = {
      "prop": {
        "Total": 100000
        "_poo": 1212
      }
    }
    segmentTree = new SegmentTree(segmentTreeSpec)
    expect(segmentTree.valueOf().prop).to.deep.equal({
      "Total": 100000
    })

  it "self cleans", ->
    segmentTreeSpec = {
      "prop": {
        "Total": 100000
      }
      "splits": [
        {
          "prop": {
            "Cut": "Ideal",
            "Count": 21551
          }
        },
        {
          "prop": {
            "Cut": "Premium",
            "Count": 13791
          }
        }
      ]
    }
    segmentTree = new SegmentTree(segmentTreeSpec)
    segmentTree._stuff = 'poop'
    segmentTree.splits[0]._note = 'woop'
    segmentTree.selfClean()
    expect(segmentTree._stuff).to.not.exist
    expect(segmentTree.splits[0]._note).to.not.exist

