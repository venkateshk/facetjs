{ expect } = require("chai")

facet = require('../../build/facet')
{ Expression } = facet

toJS = (sep) ->
  return sep unless sep
  return {
    included: sep.included.toJS()
    excluded: sep.excluded.toJS()
  }

describe "separate", ->
  it 'throws on bad input', ->
    expect(->
      Expression.TRUE.separateViaAnd()
    ).to.throw('must have refName')

  it 'works with TRUE expression', ->
    ex = Expression.TRUE

    expect(toJS(ex.separateViaAnd('venue'))).to.deep.equal(toJS({
      included: Expression.TRUE
      excluded: Expression.TRUE
    }))

  it 'works with FALSE expression', ->
    ex = Expression.FALSE

    expect(toJS(ex.separateViaAnd('venue'))).to.deep.equal(toJS({
      included: Expression.TRUE
      excluded: Expression.FALSE
    }))

  it 'works on a single included expression', ->
    ex = facet('venue').is('Google')

    expect(toJS(ex.separateViaAnd('venue'))).to.deep.equal(toJS({
      included: ex
      excluded: Expression.TRUE
    }))

  it 'works on a single excluded expression', ->
    ex = facet('venue').is('Google')

    expect(toJS(ex.separateViaAnd('make'))).to.deep.equal(toJS({
      included: Expression.TRUE
      excluded: ex
    }))

  it 'works on a small AND expression', ->
    ex = facet('venue').is('Google').and(facet('country').is('USA'))

    expect(toJS(ex.separateViaAnd('country'))).to.deep.equal(toJS({
      included: facet('country').is('USA')
      excluded: facet('venue').is('Google')
    }))

  it 'works on an AND expression', ->
    ex = facet('venue').is('Google').and(facet('country').is('USA'), facet('state').is('California'))

    expect(toJS(ex.separateViaAnd('country'))).to.deep.equal(toJS({
      included: facet('country').is('USA')
      excluded: facet('state').is('California').and(facet('venue').is('Google'))
    }))

  it 'extracts a NOT expression', ->
    ex = facet('venue').is('Google').and(facet('country').is('USA').not(), facet('state').is('California'))

    expect(toJS(ex.separateViaAnd('country'))).to.deep.equal(toJS({
      included: facet('country').is('USA').not()
      excluded: facet('state').is('California').and(facet('venue').is('Google'))
    }))

  it 'does not work on mixed OR expression', ->
    ex = facet('venue').is('Google').or(facet('country').is('USA'), facet('state').is('California'))

    expect(toJS(ex.separateViaAnd('country'))).to.deep.equal(null)

  it 'works on mixed OR filter (all in)', ->
    ex = facet('venue').is('Apple').or(facet('venue').is('Google').not())

    expect(toJS(ex.separateViaAnd('venue'))).to.deep.equal(toJS({
      included: ex
      excluded: Expression.TRUE
    }))

  it 'works on mixed OR filter (all out)', ->
    ex = facet('venue').is('Google').or(facet('country').is('USA'), facet('state').is('California'))

    expect(toJS(ex.separateViaAnd('model'))).to.deep.equal(toJS({
      included: Expression.TRUE
      excluded: ex
    }))
