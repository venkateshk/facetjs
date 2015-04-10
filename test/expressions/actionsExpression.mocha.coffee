{ expect } = require("chai")

facet = require('../../build/facet')
{ Expression, Dataset, $ } = facet
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

  describe.skip 'simplify', ->
    it 'puts defs in front of applies', ->
      expression = $()
        .def('test', 5)
        .apply('Data', $())

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .def('test', 5)
          .apply('Data', $())
          .toJS()
      )

    it 'puts defs with less references in front of defs with more', ->
      expression = $()
        .def('z', 5)
        .def('a', $('Data').add(5))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .def('z', 5)
          .def('a', $('Data').add(5))
          .toJS()
      )

    it 'sorts defs in alphabetical order of their references if they have the same number of references', ->
      expression = $()
        .def('z', $('Data').add(5))
        .def('a', $('Test').add(7))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .def('z', $('Data').add(5))
          .def('a', $('Test').add(7))
          .toJS()
      )

    it 'sorts defs in alphabetical order, all else equal', ->
      expression = $()
        .def('z', 5)
        .def('a', 7)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        expression = $()
          .def('a', 7)
          .def('z', 5)
          .toJS()
      )

    it 'merges filters', ->
      expression = $()
        .filter($('Country').is('USA'))
        .apply('Data', $())
        .filter($('Device').is('iPhone'))
        .apply('Count', 5)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .filter($('Country').is('USA').and($('Device').is('iPhone')))
          .apply('Count', 5)
          .apply('Data', $())
          .toJS()
      )

    it 'reorders sort', ->
      expression = $()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .apply('X', 5)
          .sort('$X', 'descending')
          .apply('Y', '$y')
          .toJS()
      )

    it 'puts sort and limit together', ->
      expression = $()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')
        .apply('Z', 5)
        .limit(10)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .apply('X', 5)
          .sort('$X', 'descending')
          .limit(10)
          .apply('Z', 5)
          .apply('Y', '$y')
          .toJS()
      )

    it 'topological sort', ->
      expression = $()
        .apply('Y', $('X').add('$Z'))
        .apply('X', $('A'))
        .apply('Z', 5)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        $()
          .apply('Z', 5)
          .apply('X', $('A'))
          .apply('Y', $('X').add('$Z'))
          .toJS()
      )
