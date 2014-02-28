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

  it "cleans and upgrades time props", ->
    segmentTreeSpec = {
      "prop": {
        "Total": 100000
        "_poo": 1212
        "timerange": ['2014-02-24T00:00:00Z', '2014-02-28T00:00:00Z']
      }
    }
    segmentTree = new SegmentTree(segmentTreeSpec)
    expect(segmentTree.prop['timerange']).to.deep.equal([
      new Date('2014-02-24T00:00:00Z')
      new Date('2014-02-28T00:00:00Z')
    ])
    expect(segmentTree.valueOf().prop).to.deep.equal({
      "Total": 100000
      "timerange": [
        new Date('2014-02-24T00:00:00Z')
        new Date('2014-02-28T00:00:00Z')
      ]
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

  it "computes subtree", ->
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
    expect(segmentTree.isSubTree(segmentTree)).to.equal(true)
    expect(segmentTree.isSubTree(segmentTree.splits[0])).to.equal(true)
    expect(segmentTree.isSubTree(segmentTree.splits[0].splits[0])).to.equal(true)
    expect(segmentTree.splits[0].isSubTree(segmentTree)).to.equal(false)
    expect(segmentTree.splits[0].isSubTree(segmentTree.splits[1])).to.equal(false)

  it "computes depth", ->
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
    expect(segmentTree.getDepth()).to.equal(0)
    expect(segmentTree.splits[0].getDepth()).to.equal(1)
    expect(segmentTree.splits[0].splits[0].getDepth()).to.equal(2)

