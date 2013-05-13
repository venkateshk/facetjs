chai = require("chai")
expect = chai.expect
driverUtil = require('../../../target/driverUtil')
data = require('../data')

describe "Utility tests", ->
  @timeout(40 * 1000)

  describe "flatten", ->
    it "should produce the same result", -> (test) ->
      test.expect(2)
      test.deepEqual(driverUtil.flatten([]), [], "flatten works")
      test.deepEqual(driverUtil.flatten([[1,3], [3,6,7]]), [1,3,3,6,7], "flatten works")
      test.done()
      return

  describe "inPlaceTrim", ->
    it "should produce the same result", -> (test) ->
      test.expect(3)

      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 2)
      test.deepEqual(a, [1, 2], "Trim down")

      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 0)
      test.deepEqual(a, [], "Trim down to 0")

      driverUtil.inPlaceTrim(a = [1, 2, 3, 4], 10)
      test.deepEqual(a, [1, 2, 3, 4], "Trim above length")

      test.done()
      return

  describe "Table", ->
    it "should produce the same result", -> {
      "Basic Rectangular Table": (test) ->
        test.expect(4)
        query = data.diamond[1].query
        root = data.diamond[1].data
        table = new driverUtil.Table {
          root
          query
        }

        test.deepEqual(["Cut", "Count"], table.columns, "Columns of the table is incorrect")
        test.deepEqual([
          { Count: 1, Cut: 'A' }
          { Count: 2, Cut: 'B' }
          { Count: 3, Cut: 'C' }
          { Count: 4, Cut: 'D' }
          { Count: 5, Cut: 'E' }
          { Count: 6, Cut: 'F"' }
        ], table.data, "Data of the table is incorrect")
        test.deepEqual('"Cut","Count"\r\n"A","1"\r\n"B","2"\r\n"C","3"\r\n"D","4"\r\n"E","5"\r\n"F\"\"","6"',
          table.toTabular(','),
          "CSV of the table is incorrect")
        test.deepEqual('"Cut"\t"Count"\r\n"A"\t"1"\r\n"B"\t"2"\r\n"C"\t"3"\r\n"D"\t"4"\r\n"E"\t"5"\r\n"F\"\""\t"6"',
          table.toTabular('\t'),
          "TSV of the table is incorrect")
        test.done()
        return

      "Inheriting properties": (test) ->
        test.expect(3)
        query = data.diamond[2].query
        root = data.diamond[2].data
        table = new driverUtil.Table {
          root
          query
        }

        test.deepEqual(["Carat", "Cut", "Count"], table.columns, "Columns of the table is incorrect")
        test.deepEqual(data.diamond[2].tabular, table.data, "Data of the table is incorrect")
        test.deepEqual(data.diamond[2].csv, table.toTabular(','), "CSV of the table is incorrect")
        test.done()
        return
    }
