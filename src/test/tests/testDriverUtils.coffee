driverUtil = require('../../driverUtil')
data = require('../data')

exports["Table Tests"] = {
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
      ["A", 1]
      ["B", 2]
      ["C", 3]
      ["D", 4]
      ["E", 5]
      ["F\"", 6]
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
    test.deepEqual(data.diamond[2].csv,
      table.toTabular(','),
      "CSV of the table is incorrect")
    test.done()
    return
}
