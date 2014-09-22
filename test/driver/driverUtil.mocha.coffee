{ expect } = require("chai")

{ FacetQuery } = require('../../build/query')
driverUtil = require('../../build/driver/driverUtil')
{ Table } = driverUtil
data = require('../data')

describe "Utility", ->
  describe "flatten", ->
    it "should work on an empty list", ->
      expect(driverUtil.flatten([])).to.deep.equal([])

    it "should work on a list of an empty list", ->
      expect(driverUtil.flatten([[]])).to.deep.equal([])

    it "should work on a list of empty lists", ->
      expect(driverUtil.flatten([[], []])).to.deep.equal([])

    it "should work on a normal list", ->
      expect(driverUtil.flatten([[1,3], [3,6,7]])).to.deep.equal([1,3,3,6,7])

    it "should throw on a mixed list", ->
      expect(-> driverUtil.flatten([[1,3], 0, [3,6,7]])).to.throw()


  describe "inPlaceTrim", ->
    it "should trim down", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 2)
      expect(a).to.deep.equal([1, 2])

    it "should trim down to 0", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 0)
      expect(a).to.deep.equal([])

    it "should trim above length", ->
      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 10)
      expect(a).to.deep.equal([1, 2, 3, 4])


  describe "safeAdd", ->
    it "works on 0.2 + 0.1", ->
      expect(driverUtil.safeAdd(0.2, 0.1)).to.equal(0.3)
      expect(driverUtil.safeAdd(0.2, 0.1)).to.not.equal(0.2 + 0.1)

    it "works on 0.7 + 0.1", ->
      expect(driverUtil.safeAdd(0.7, 0.1)).to.equal(0.8)
      expect(driverUtil.safeAdd(0.7, 0.1)).to.not.equal(0.7 + 0.1)

    it "works on unrepresentable", ->
      expect(driverUtil.safeAdd(1, 1/3)).to.equal(1 + 1/3)


  describe "datesToInterval", ->
    it "should simplify round dates", ->
      expect(driverUtil.datesToInterval(
        new Date("2013-02-26T00:00:00Z")
        new Date("2013-02-27T00:00:00Z")
      )).to.equal('2013-02-26/2013-02-27')

    it "should work for general dates", ->
      expect(driverUtil.datesToInterval(
        new Date("2013-02-26T01:01:01")
        new Date("2013-02-27T02:02:02")
      )).to.equal('2013-02-26T01:01:01/2013-02-27T02:02:02')


  describe "timeFilterToIntervals", ->
    it "should work for simple within filter", ->
      expect(driverUtil.timeFilterToIntervals({
        type: 'within'
        attribute: 'time'
        range: [
          new Date("2013-02-26T00:00:00Z")
          new Date("2013-02-27T00:00:00Z")
        ]
      })).to.deep.equal(["2013-02-26/2013-02-27"])


  describe "continuousFloorExpression", ->
    it "should be minimalistic (no size / no offset)", ->
      expect(driverUtil.continuousFloorExpression("x", "Math.floor", 1, 0)).to.equal('Math.floor(x)')

    it "should be minimalistic (no size)", ->
      expect(driverUtil.continuousFloorExpression("x", "Math.floor", 1, 0.3)).to.equal('Math.floor(x - 0.3) + 0.3')

    it "should be minimalistic (no offset)", ->
      expect(driverUtil.continuousFloorExpression("x", "Math.floor", 5, 0)).to.equal('Math.floor(x / 5) * 5')

    it "should be work in general", ->
      expect(driverUtil.continuousFloorExpression("x", "Math.floor", 5, 3)).to.equal('Math.floor((x - 3) / 5) * 5 + 3')


  describe "Table", ->
    query = FacetQuery.fromJS([
      { operation: 'split', name: 'Cut', bucket: 'identity', attribute: 'cut' }
      { operation: 'apply', name: 'Count', aggregate: 'count' }
      { operation: 'combine', method: 'slice', sort: { prop: 'Cut', compare: 'natural', direction: 'descending' } }
    ])

    response = {
      prop: { Count: 21 }
      splits: [
        { prop: { Cut: 'A', Count: 1 } }
        { prop: { Cut: 'B', Count: 2 } }
        { prop: { Cut: 'C', Count: 3 } }
        { prop: { Cut: 'D', Count: 4 } }
        { prop: { Cut: 'E', Count: 5 } }
        { prop: { Cut: 'J "F" L', Count: 6 } }
      ]
    }

    it "works with no split", ->
      table = new Table({
        query: FacetQuery.fromJS([
          {"operation":"apply","name":"Count","aggregate":"sum","attribute":"count"}
          {"operation":"apply","name":"Added","aggregate":"sum","attribute":"added"}
        ])
        root: { prop: { Count: 300223, Added: 125714717 } }
      })

      expect(table.data).to.deep.equal([
        { Count: 300223, Added: 125714717 }
      ])

      expect(table.toTabular(',', '\n')).to.equal(
        """
        "Count","Added"
        "300223","125714717"
        """
      )

    it "basically works", ->
      table = new Table({
        query
        root: response
      })

      expect(table.data).to.deep.equal([
        { Count: 1, Cut: 'A' }
        { Count: 2, Cut: 'B' }
        { Count: 3, Cut: 'C' }
        { Count: 4, Cut: 'D' }
        { Count: 5, Cut: 'E' }
        { Count: 6, Cut: 'J "F" L' }
      ])

      expect(table.toTabular(',', '\n')).to.equal(
        """
        "Cut","Count"
        "A","1"
        "B","2"
        "C","3"
        "D","4"
        "E","5"
        "J ""F"" L","6"
        """
      )

      expect(table.toTabular('\t', '\n')).to.equal(
        """
        "Cut"\t"Count"
        "A"\t"1"
        "B"\t"2"
        "C"\t"3"
        "D"\t"4"
        "E"\t"5"
        "J ""F"" L"\t"6"
        """
      )

    it "inherits properties", ->
      table = new Table({
        query: FacetQuery.fromJS(data.diamond.query)
        root: data.diamond.data
      })

      expect(table.data).to.deep.equal(data.diamond.tabular)
      expect(table.toTabular(',', '\n')).to.equal(data.diamond.csv)

    it "translates columns if @translateFn is set (trivial)", ->
      table = new Table({
        query
        root: response
      })

      table.columnTitle ({name}) ->
        map = {"Cut": "Cut"}
        return map[name]

      table.translate((_, datum) -> '_')

      expect(table.toTabular('\t', '\n')).to.deep.equal(
        """
        "Cut"
        "_"
        "_"
        "_"
        "_"
        "_"
        "_"
        """
      )

    it "translates columns if @translateFn is set", ->
      table = new Table({
        query
        root: response
      })

      table.columnTitle ({name}) ->
        map = {"Cut": "Cut"}
        return map[name]

      table.translate((_, datum) -> "[#{datum}]")

      expect(table.toTabular('\t', '\n')).to.deep.equal(
        """
        "Cut"
        "[A]"
        "[B]"
        "[C]"
        "[D]"
        "[E]"
        "[J ""F"" L]"
        """
      )

    it "maps column names", ->
      table = new Table({
        query
        root: response
      })

      table.columnTitle ({name}) ->
        map = {
          "Cut": "Cut_Test"
          "Count": 'Count_"Test"_'
        }
        return map[name]

      expect(table.toTabular('\t', '\n')).to.deep.equal(
        """
        "Cut_Test"\t"Count_""Test""_"
        "A"\t"1"
        "B"\t"2"
        "C"\t"3"
        "D"\t"4"
        "E"\t"5"
        "J ""F"" L"\t"6"
        """
      )

    it "skips columns", ->
      table = new Table({
        query
        root: response
      })

      table.columnTitle ({name}) ->
        map = {
          "Cut": "Cut_Test"
        }
        return map[name]

      expect(table.toTabular('\t', '\n')).to.deep.equal(
        """
        "Cut_Test"
        "A"
        "B"
        "C"
        "D"
        "E"
        "J ""F"" L"
        """
      )

    it.skip "works with 'big data'", ->
      root = {
        prop: { Count: 200000 }
        splits: []
      }
      num = 5000001
      while num -= 1
        root.splits.push { prop: { Cut: 'A', Count: 1 } }

      expect(->
        table = new Table({
          root
          query
        })
      ).not.to.throw()
