{ expect } = require("chai")

{ testHigherObjects } = require("higher-object/build/tester")

facet = require('../../../build/facet')
{ Action } = facet.Core

describe "Actions", ->
  it "passes higher object tests", ->
    testHigherObjects(Action, [
      {
        action: 'apply'
        name: 'Five'
        expression: { op: 'literal', value: 5 }
      }
      {
        action: 'filter'
        expression: {
          op: 'is'
          lhs: { op: 'ref', name: 'myVar' }
          rhs: { op: 'literal', value: 5 }
        }
      }
      {
        action: 'sort'
        expression: { op: 'ref', name: 'myVar' }
        direction: 'ascending'
      }
      {
        action: 'limit'
        limit: 10
      }
    ], {
      newThrows: true
    })