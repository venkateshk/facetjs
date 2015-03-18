{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../../build/facet')
{ Expression, Dataset, TimeRange } = facet.core

context = {
  wiki: Dataset.fromJS({
    source: 'druid',
    dataSource: 'wikipedia_editstream',
    timeAttribute: 'time',
    forceInterval: true,
    approximate: true,
    context: null
    attributes: {
      time: { type: 'TIME' }
      language: { type: 'STRING' }
      page: { type: 'STRING' }
      added: { type: 'NUMBER' }
    }
    filter: facet('time').in(TimeRange.fromJS({
      start: new Date("2013-02-26T00:00:00Z")
      end: new Date("2013-02-27T00:00:00Z")
    }))
  })
}

describe "RemoteDataset", ->
  describe "simplifies / digests", ->
    it "a total", ->
      ex = facet()
        .def("wiki",
          facet('^wiki')
            .apply('addedTwice', '$added * 2')
            .filter(facet("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('TotalAdded', '$wiki.sum($added)')

      ex = ex.referenceCheck(context).resolve(context).simplify()

      remoteDataset = ex.value
      expect(remoteDataset.derivedAttributes).to.have.length(1)
      expect(remoteDataset.defs).to.have.length(1)
      expect(remoteDataset.applies).to.have.length(2)

      expect(remoteDataset.simulate().toJS()).to.deep.equal([
        {
          "Count": 4
          "TotalAdded": 4
        }
      ])

    it "a split on string", ->
      ex = facet('wiki').split("$page", 'Page')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('literal')
      remoteDataset = ex.value
      expect(remoteDataset.defs).to.have.length(1)
      expect(remoteDataset.applies).to.have.length(2)

      expect(remoteDataset.simulate().toJS()).to.deep.equal([
        "Added": 4
        "Count": 4
        "Page": "some_page"
      ])

    it "a split on time", ->
      ex = facet('wiki').split(facet("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('literal')
      remoteDataset = ex.value
      expect(remoteDataset.defs).to.have.length(1)
      expect(remoteDataset.applies).to.have.length(2)

      expect(remoteDataset.simulate().toJS()).to.deep.equal([
        {
          "Added": 4
          "Count": 4
          "Timestamp": {
            "start": new Date('2015-03-13T07:00:00.000Z')
            "end": new Date('2015-03-14T07:00:00.000Z')
            "type": "TIME_RANGE"
          }
        }
      ])

    it "a total and a split", ->
      ex = facet()
        .def("wiki",
          facet('^wiki')
            .apply('addedTwice', '$added * 2')
            .filter(facet("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('TotalAdded', '$wiki.sum($added)')
        .apply('Pages',
          facet('wiki').split("$page", 'Page')
            .apply('Count', '$wiki.count()')
            .apply('Added', '$wiki.sum($added)')
            .sort('$Count', 'descending')
            .limit(5)
        )

      ex = ex.referenceCheck(context).resolve(context).simplify()

      expect(ex.op).to.equal('actions')
      expect(ex.actions).to.have.length(2)

      remoteDataset = ex.operand.value
      expect(remoteDataset.defs).to.have.length(1)
      expect(remoteDataset.applies).to.have.length(2)
