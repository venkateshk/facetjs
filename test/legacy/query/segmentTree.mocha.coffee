{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ FacetQuery, SegmentTree } = facet.legacy

describe "SegmentTree", ->
  it "passes higher object tests", ->
    testHigherObjects(SegmentTree, [
      {
        "prop": {
          "Clarity": "VS2",
          "Count": 5071
        }
      },
      {
        "prop": {
          "Clarity": null,
          "Count": 5071
        },
        "isOthers": true
      },
      {
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
    ])

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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec)
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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec)
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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec)
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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec)
    expect(segmentTree.isSubTreeOf(segmentTree)).to.equal(true)
    expect(segmentTree.isSubTreeOf(segmentTree.splits[0])).to.equal(true)
    expect(segmentTree.isSubTreeOf(segmentTree.splits[0].splits[0])).to.equal(true)
    expect(segmentTree.splits[0].isSubTreeOf(segmentTree)).to.equal(false)
    expect(segmentTree.splits[0].isSubTreeOf(segmentTree.splits[1])).to.equal(false)

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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec)
    expect(segmentTree.getParentDepth()).to.equal(0)
    expect(segmentTree.splits[0].getParentDepth()).to.equal(1)
    expect(segmentTree.splits[0].splits[0].getParentDepth()).to.equal(2)

    expect(segmentTree.getMaxDepth()).to.equal(3)
    expect(segmentTree.splits[0].getMaxDepth()).to.equal(2)
    expect(segmentTree.splits[0].splits[0].getMaxDepth()).to.equal(1)

  it "computes trims to depth", ->
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
    segmentTree = SegmentTree.fromJS(segmentTreeSpec).trimToMaxDepth(2)
    expect(segmentTree.toJS()).to.deep.equal({
      "prop": {},
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
    })

  describe 'hasOthers', ->
    it 'returns true when there is a Others child segmentTree in splits', ->

      segmentTreeSpec = {
        "prop": {
          "Count": 50000
        },
        "splits": [
          {
            "prop": {
              "Cut": "Ideal",
              "Count": 20000
            }
          },
          {
            "prop": {
              "Cut": "Premium",
              "Count": 10000
            }
          }
          {
            "prop": {
              "Cut": null,
              "Count": 20000
            }
            "isOthers": true
          }
        ]
      }
      segmentTree = SegmentTree.fromJS(segmentTreeSpec)
      expect(segmentTree.hasOthers()).to.be.true

    it 'returns false when there isn\'t a Others child segmentTree in splits', ->
      segmentTreeSpec = {
        "prop": {
          "Count": 50000
        },
        "splits": [
          {
            "prop": {
              "Cut": "Ideal",
              "Count": 20000
            }
          },
          {
            "prop": {
              "Cut": "Premium",
              "Count": 10000
            }
          }
        ]
      }
      segmentTree = SegmentTree.fromJS(segmentTreeSpec)
      expect(segmentTree.hasOthers()).to.be.false

  describe "isPropValueEqual", ->
    it "should work on strings", ->
      pv1 = "Facet"
      pv2 = "Facet"
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(true)

      pv1 = "Facet"
      pv2 = "Bacet"
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

    it "should work on numbers", ->
      pv1 = 5
      pv2 = 5.0
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(true)

      pv1 = 1.2
      pv2 = 7
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

    it "should work on number ranges", ->
      pv1 = [1, 1.5]
      pv2 = [1, 1.5]
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(true)

      pv1 = [1, 1.5]
      pv2 = 3
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

      pv1 = 3
      pv2 = [1, 1.5]
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

      pv1 = [1, 1.5, 'blah']
      pv2 = [1, 1.5]
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

      pv1 = [1, 1.5]
      pv2 = ['1', '1.5']
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)

    it "should work on date ranges", ->
      pv1 = [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
      pv2 = [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(true)

      pv1 = [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:00Z")]
      pv2 = [new Date("2013-02-26T00:00:00Z"), new Date("2013-02-27T00:00:01Z")]
      expect(SegmentTree.isPropValueEqual(pv1, pv2)).to.equal(false)


  describe "isPropValueIn", ->
    it "should work on strings", ->
      propValue = "Facet"
      propValueList = ["Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(true)

      propValue = "Facet"
      propValueList = []
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(false)

      propValue = "Facet"
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(true)

      propValue = "Bacet"
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(false)

    it "should work on null", ->
      propValue = null
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(true)

    it "should work on ranges", ->
      propValue = [1, 1.05]
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(true)

      propValue = [1.05, 1.1]
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(false)

      propValue = [1, 1.1]
      propValueList = [1, null, [1, 1.05], "Facet"]
      expect(SegmentTree.isPropValueIn(propValue, propValueList)).to.equal(false)
