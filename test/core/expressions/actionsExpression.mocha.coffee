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
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .def('test', 5)
          .apply('Data', facet())
          .toJS()
      )

    it 'puts defs with less references in front of defs with more', ->
      expression = facet()
        .def('z', 5)
        .def('a', facet('Data').add(5))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .def('z', 5)
          .def('a', facet('Data').add(5))
          .toJS()
      )

    it 'sorts defs in alphabetical order of their references if they have the same number of references', ->
      expression = facet()
        .def('z', facet('Data').add(5))
        .def('a', facet('Test').add(7))

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .def('z', facet('Data').add(5))
          .def('a', facet('Test').add(7))
          .toJS()
      )

    it 'sorts defs in alphabetical order, all else equal', ->
      expression = facet()
        .def('z', 5)
        .def('a', 7)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        expression = facet()
          .def('a', 7)
          .def('z', 5)
          .toJS()
      )

    it 'merges filters', ->
      expression = facet()
        .filter(facet('Country').is('USA'))
        .apply('Data', facet())
        .filter(facet('Device').is('iPhone'))
        .apply('Count', 5)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .filter(facet('Country').is('USA').and(facet('Device').is('iPhone')))
          .apply('Count', 5)
          .apply('Data', facet())
          .toJS()
      )

    it 'reorders sort', ->
      expression = facet()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .apply('X', 5)
          .sort('$X', 'descending')
          .apply('Y', '$y')
          .toJS()
      )

    it 'puts sort and limit together', ->
      expression = facet()
        .apply('X', 5)
        .apply('Y', '$y')
        .sort('$X', 'descending')
        .apply('Z', 5)
        .limit(10)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .apply('X', 5)
          .sort('$X', 'descending')
          .limit(10)
          .apply('Z', 5)
          .apply('Y', '$y')
          .toJS()
      )

    it 'topological sort', ->
      expression = facet()
        .apply('Y', facet('X').add('$Z'))
        .apply('X', facet('A'))
        .apply('Z', 5)

      simplifiedExpression = expression.simplify().toJS()
      expect(simplifiedExpression).to.deep.equal(
        facet()
          .apply('Z', 5)
          .apply('X', facet('A'))
          .apply('Y', facet('X').add('$Z'))
          .toJS()
      )
