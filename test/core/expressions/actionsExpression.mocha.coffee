{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.core
tests = require './sharedTests'

describe 'ActionsExpression', ->
  describe 'with simple query', ->
    beforeEach ->
      this.expression = {
        op: 'actions'
        operand: '$diamonds'
        actions: [
          { action: 'apply', name: 'five', expression: { op: 'add', operands: [5, 1] } }
        ]
      }

    tests.complexityIs(2)
    tests.simplifiedExpressionIs({
      op: 'actions'
      operand: {
        op: 'ref'
        name: 'diamonds'
      }
      actions: [
        { action: 'apply', name: 'five', expression: { op: 'literal', value: 6 } }
      ]
    })

  describe 'simplify', ->
    it 'puts defs in front of applies', ->
      expression = facet()
        .def('test', 5)
        .apply('Data', facet())

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "def",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "test"
        },
        {
          "action": "apply",
          "expression": {
            "op": "literal",
            "value": {
              "dataset": "native",
              "data": [
                {}
              ]
            },
            "type": "DATASET"
          },
          "name": "Data"
        }
      ])

    it 'puts defs with less references in front of defs with more', ->
      expression = facet()
        .def('z', 5)
        .def('a', facet('Data').add(5))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "def",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "z"
        },
        {
          "action": "def",
          "expression": {
            "op": "add",
            "operands": [
              {
                "op": "ref",
                "name": "Data"
              },
              {
                "op": "literal",
                "value": 5
              }
            ]
          },
          "name": "a"
        }
      ])

    it 'sorts defs in alphabetical order of their references if they have the same number of references', ->
      expression = facet()
      .def('z', facet('Data').add(5))
      .def('a', facet('Test').add(7))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "def",
          "expression": {
            "op": "add",
            "operands": [
              {
                "op": "ref",
                "name": "Data"
              },
              {
                "op": "literal",
                "value": 5
              }
            ]
          },
          "name": "z"
        }
        {
          "action": "def",
          "expression": {
            "op": "add",
            "operands": [
              {
                "op": "ref",
                "name": "Test"
              },
              {
                "op": "literal",
                "value": 7
              }
            ]
          },
          "name": "a"
        }
      ])

    it 'sorts defs in alphabetical order, all else equal', ->
      expression = facet()
      .def('z', 5)
      .def('a', 7)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "def",
          "expression": {
            "op": "literal",
            "value": 7
          },
          "name": "a"
        },
        {
          "action": "def",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "z"
        }
      ])

    # filter -> filter -> apply
    # ->
    # filter -> apply
    it 'merges filters', ->
      expression = facet()
        .filter(facet('Data').greaterThanOrEqual(5))
        .filter(facet('Data').lessThan(8))
        .apply('Data', facet())
        .apply('Count', 5)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "apply",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "Count"
        },
        {
          "action": "apply",
          "expression": {
            "op": "literal",
            "value": {
              "dataset": "native",
              "data": [
                {}
              ]
            },
            "type": "DATASET"
          },
          "name": "Data"
        },
        {
          "action": "filter",
          "expression": {
            "op": "in",
            "lhs": {
              "op": "ref",
              "name": "Data"
            },
            "rhs": {
              "op": "literal",
              "value": {
                "start": 5,
                "end": 8
              },
              "type": "NUMBER_RANGE"
            }
          }
        }
      ])

    #.apply('X', '$data.sum($x)').apply('Y', '$data.sum($y)').sort('$X', 'descending')
    # ->
    #.apply('X', '$data.sum($x)').sort('$X', 'descending').apply('Y', '$data.sum($y)')
    it 'reorders sort', ->
      expression = facet()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "apply",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "X"
        },
        {
          "action": "sort",
          "expression": {
            "op": "ref",
            "name": "X"
          },
          "direction": "descending"
        }
        {
          "action": "apply",
          "expression": {
            "op": "ref",
            "name": "y"
          },
          "name": "Y"
        },
      ])

    #.apply('X', '$data.sum($x)').apply('Y', '$data.sum($y)').sort('$X', 'descending').limit(10)
    # ->
    #.apply('X', '$data.sum($x)').sort('$X', 'descending').limit(10).apply('Y', '$data.sum($y)')
    it 'puts sort and limit together', ->
      expression = facet()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')
        .limit(10)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression.actions).to.deep.equal([
        {
          "action": "apply",
          "expression": {
            "op": "literal",
            "value": 5
          },
          "name": "X"
        },
        {
          "action": "sort",
          "expression": {
            "op": "ref",
            "name": "X"
          },
          "direction": "descending"
        },
        {
          "action": "limit",
          "limit": 10
        },
        {
          "action": "apply",
          "expression": {
            "op": "ref",
            "name": "y"
          },
          "name": "Y"
        }
      ])
