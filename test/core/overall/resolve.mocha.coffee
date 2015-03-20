{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset, NativeDataset } = facet.core

describe "resolve", ->
  describe "errors if", ->
    it "went too deep", ->
      ex = facet()
        .apply('num', '$^foo + 1')
        .apply('subData',
          facet()
            .apply('x', '$^num * 3')
            .apply('y', '$^^^foo * 10')
        )

      expect(->
        ex.resolve({ foo: 7 })
      ).to.throw('went too deep during resolve on: $^^^foo')

    it "could not find something in context", ->
      ex = facet()
        .apply('num', '$^foo + 1')
        .apply('subData',
          facet()
            .apply('x', '$^num * 3')
            .apply('y', '$^^foobar * 10')
        )

      expect(->
        ex.resolve({ foo: 7 })
      ).to.throw('could not resolve $^^foobar because is was not in the context')

    it "ended up with bad types", ->
      ex = facet()
        .apply('num', '$^foo + 1')
        .apply('subData',
          facet()
            .apply('x', '$^num * 3')
            .apply('y', '$^^foo * 10')
        )

      expect(->
        ex.resolve({ foo: 'bar' })
      ).to.throw('add must have an operand of type NUMBER at position 0')


  describe "resolves", ->
    it "works in a basic case", ->
      ex = facet('foo').add('$bar')

      context = {
        foo: 7
      }

      ex = ex.resolve(context, true)
      expect(ex.toJS()).to.deep.equal(
        facet(7).add('$bar').toJS()
      )

    it "works in a basic case (and simplifies)", ->
      ex = facet('foo').add(3)

      context = {
        foo: 7
      }

      ex = ex.resolve(context, true).simplify()
      expect(ex.toJS()).to.deep.equal(
        facet(10).toJS()
      )

    it "works in a basic actions case", ->
      ex = facet()
        .apply('num', '$^foo + 1')
        .apply('subData',
          facet()
            .apply('x', '$^num * 3')
            .apply('y', '$^^foo * 10')
        )

      context = {
        foo: 7
      }

      ex = ex.resolve(context)
      expect(ex.toJS()).to.deep.equal(
        facet()
          .apply('num', '7 + 1')
          .apply('subData',
            facet()
              .apply('x', '$^num * 3')
              .apply('y', '7 * 10')
          )
          .toJS()
      )

      ex = ex.simplify()
      expect(ex.toJS()).to.deep.equal(
        facet()
          .apply('num', 8)
          .apply('subData',
            facet()
              .apply('x', '$^num * 3')
              .apply('y', 70)
          )
          .toJS()
      )

    it "works in a basic actions case (in $def)", ->
      ex = facet()
        .apply('num', '$^foo + 1')
        .apply('subData',
          facet()
            .apply('x', '$^num * 3')
            .apply('y', '$^^foo * 10')
        )

      context = {
        $def: { foo: 7 }
      }

      ex = ex.resolve(context)
      expect(ex.toJS()).to.deep.equal(
        facet()
          .apply('num', '7 + 1')
          .apply('subData',
            facet()
              .apply('x', '$^num * 3')
              .apply('y', '7 * 10')
          )
          .toJS()
      )

      
  describe.only "resolves remotes", ->
    context = {
      diamonds: Dataset.fromJS({
        source: 'druid',
        dataSource: 'diamonds',
        timeAttribute: 'time',
        forceInterval: true,
        approximate: true,
        context: null
        attributes: {
          time: { type: 'TIME' }
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'NUMBER' }
        }
      })
      diamonds2: Dataset.fromJS({
        source: 'druid',
        dataSource: 'diamonds2',
        timeAttribute: 'time',
        forceInterval: true,
        approximate: true,
        context: null
        attributes: {
          time: { type: 'TIME' }
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'NUMBER' }
        }
      })
    }

    it "resolves all remotes correctly", ->
      ex = facet()
        .apply('Cuts',
          facet("diamonds").split("$cut", 'Cut')
            .apply('Count', facet('diamonds').count())
            .sort('$Count', 'descending')
            .limit(10)
        )
        .apply('Carats',
          facet("diamonds").split(facet('carat').numberBucket(0.5), 'Carat')
            .apply('Count', facet('diamonds').count())
            .sort('$Count', 'descending')
            .limit(10)
        )

      ex = ex.referenceCheck(context)

      expect(ex.every((e) ->
        return (String(e.remote) is 'druid:diamonds') if e.isOp('ref')
        return null
      )).to.equal(true)

    it "resolves two dataset remotes", ->
      ex = facet()
        .apply('Cuts',
          facet("diamonds").split("$cut", 'Cut')
            .apply('Count', facet('diamonds').count())
            .sort('$Count', 'descending')
            .limit(10)
        )
        .apply('Carats',
          facet("diamonds2").split(facet('carat').numberBucket(0.5), 'Carat')
            .apply('Count', facet('diamonds2').count())
            .sort('$Count', 'descending')
            .limit(10)
        )

      ex = ex.referenceCheck(context)

      expect(ex.actions[0].expression.every((e) ->
        return (String(e.remote) is 'druid:diamonds') if e.isOp('ref')
        return null
      )).to.equal(true)

      expect(ex.actions[1].expression.every((e) ->
        return (String(e.remote) is 'druid:diamonds2') if e.isOp('ref')
        return null
      )).to.equal(true)
