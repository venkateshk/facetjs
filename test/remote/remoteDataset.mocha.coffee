{ expect } = require("chai")

{ WallTime } = require('chronology')
if not WallTime.rules
  tzData = require("chronology/lib/walltime/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

facet = require('../../build/facet')
{ Expression, Dataset, TimeRange, $ } = facet

wikiDataset = Dataset.fromJS({
  source: 'druid',
  dataSource: 'wikipedia_editstream',
  timeAttribute: 'time',
  context: null
  attributes: {
    time: { type: 'TIME' }
    language: { type: 'STRING' }
    page: { type: 'STRING' }
    added: { type: 'NUMBER' }
  }
})

context = {
  wiki: wikiDataset.addFilter($('time').in(TimeRange.fromJS({
    start: new Date("2013-02-26T00:00:00Z")
    end: new Date("2013-02-27T00:00:00Z")
  })))
  wikiCmp: Dataset.fromJS({
    source: 'druid',
    dataSource: 'wikipedia_editstream_cmp',
    timeAttribute: 'time',
    context: null
    attributes: {
      time: { type: 'TIME' }
      language: { type: 'STRING' }
      page: { type: 'STRING' }
      added: { type: 'NUMBER' }
    }
    filter: $('time').in(TimeRange.fromJS({
      start: new Date("2013-02-25T00:00:00Z")
      end: new Date("2013-02-26T00:00:00Z")
    }))
  })

#  wikiDataset.addFilter($('time').in(TimeRange.fromJS({
#    start: new Date("2013-02-25T00:00:00Z")
#    end: new Date("2013-02-26T00:00:00Z")
#  })))
}

describe "RemoteDataset", ->
  describe "simplifies / digests", ->
    it "a total", ->
      ex = $()
        .def("wiki",
          $('^wiki')
            .apply('addedTwice', '$added * 2')
            .filter($("language").is('en'))
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
      ex = $('wiki').split("$page", 'Page')
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
      ex = $('wiki').split($("time").timeBucket('P1D', 'America/Los_Angeles'), 'Timestamp')
        .apply('Count', '$wiki.count()')
        .apply('Added', '$wiki.sum($added)')
        .sort('$Count', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()
      
      expect(ex.op).to.equal('actions')
      expect(ex.actions).to.have.length(2)
      remoteDataset = ex.operand.value
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
      ex = $()
        .def("wiki",
          $('^wiki')
            .apply('addedTwice', '$added * 2')
            .filter($("language").is('en'))
        )
        .apply('Count', '$wiki.count()')
        .apply('TotalAdded', '$wiki.sum($added)')
        .apply('Pages',
          $('wiki').split("$page", 'Page')
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

    it "a union of two groups", ->
      ex = $('wiki').group('$page').union($('wikiCmp').group('$page')).label('Page')
        .def('wiki', '$wiki.filter($page = $^Page)')
        .def('wikiCmp', '$wikiCmp.filter($page = $^Page)')
        .apply('Count', '$wiki.count()')
        .apply('CountDiff', '$wiki.count() - $wikiCmp.count()')
        .sort('$CountDiff', 'descending')
        .limit(5)

      ex = ex.referenceCheck(context).resolve(context).simplify()

      # console.log("ex.toString()", ex.toString());
      
      expect(ex.op).to.equal('actions')
      expect(ex.operand.op).to.equal('join')

      remoteDatasetMain = ex.operand.lhs.value
      expect(remoteDatasetMain.defs).to.have.length(1)
      expect(remoteDatasetMain.applies).to.have.length(2)

      remoteDatasetCmp = ex.operand.rhs.value
      expect(remoteDatasetCmp.defs).to.have.length(1)
      expect(remoteDatasetCmp.applies).to.have.length(1)

      expect(ex.actions[0].toString()).to.equal('.apply(CountDiff, ($_br_0 + $_br_1))')
