{ expect } = require("chai")

#{ testHigherObjects } = require("higher-object/build/tester")

{ Datum } = require('../../build/datatype/dataset')
{ TimeRange } = require('../../build/datatype/timeRange')

describe "Datum", ->
  it "works with all data types", ->
    datum = Datum.fromJS({})
    datum.Void = null
    datum.SoTrue = true
    datum.NotSoTrue = false
    datum.Count = 2353
    datum.HowAwesome = Infinity
    datum.HowLame = -Infinity
    datum.SomeTime = TimeRange.fromJS({
      start: new Date('2015-01-26T04:54:10Z')
      end:   new Date('2015-01-26T05:00:00Z')
    })

    expectedJS = {
      Void: null,
      SoTrue: true,
      NotSoTrue: false,
      Count: 2353,
      HowAwesome: { type: 'number', value: 'Infinity' },
      HowLame: { type: 'number', value: '-Infinity' },
      SomeTime: {
        type: "timeRange"
        start: new Date('2015-01-26T04:54:10Z')
        end:   new Date('2015-01-26T05:00:00Z')
      }
    }

    datumJS = datum.toJS()
    expect(datumJS).to.deep.equal(expectedJS)

    copyViaJSON = JSON.parse(JSON.stringify(datumJS, null, 2))
    
    copyDatumJS = Datum.fromJS(copyViaJSON).toJS()
    expect(copyDatumJS).to.deep.equal(expectedJS)
    