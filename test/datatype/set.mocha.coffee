{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

{ Set } = require('../../build/datatype/set')

describe "Set", ->
  it "passes higher object tests", ->
    testHigherObjects(Set, [
      {
        values: []
      }
      {
        values: ['1']
      }
      {
        values: ['2', '3']
      }
    ])

  it "union", ->
    expect(
      Set.fromJS({values: ['1', '2']}).union(Set.fromJS({values: ['2', '3']})).toJS()
    ).to.deep.equal({values: ['1', '2', '3']})

  it "intersect", ->
    expect(
      Set.fromJS({values: ['1', '2']}).intersect(Set.fromJS({values: ['2', '3']})).toJS()
    ).to.deep.equal({values: ['2']})
