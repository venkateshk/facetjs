{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression } = facet.core

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
