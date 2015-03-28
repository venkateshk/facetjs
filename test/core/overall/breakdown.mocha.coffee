{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset, NativeDataset } = facet.core

describe "breakdown", ->
  context = {
    x: 1
    y: 2
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

  it "breakdown zero datasets correctly", ->
    ex = Expression.parse('$x * $y + 2')
  
    ex = ex.referenceCheck(context)
    breakdown = ex.breakdownByDataset('b')
    expect(breakdown.byDataset).to.deep.equal({})
    expect(breakdown.combine.toString()).to.equal('(($x:NUMBER * $y:NUMBER) + 2)')

  it "breakdown one datasets correctly", ->
    ex = Expression.parse('$diamonds.count() * 2')

    ex = ex.referenceCheck(context)
    breakdown = ex.breakdownByDataset('b')
    expect(breakdown.byDataset).to.have.keys('druid:diamonds')
    expect(breakdown.byDataset['druid:diamonds'].join(' | ')).to.equal(
      '.apply(b0, ($diamonds:DATASET.count() * 2))'
    )
    expect(breakdown.combine.toString()).to.equal('$b0')

  it "breakdown two datasets correctly", ->
    ex = Expression.parse('$diamonds.count() * $diamonds2.count() + $diamonds.sum($carat)')

    ex = ex.referenceCheck(context)
    breakdown = ex.breakdownByDataset('b')
    expect(breakdown.byDataset).to.have.keys('druid:diamonds', 'druid:diamonds2')
    expect(breakdown.byDataset['druid:diamonds'].join(' | ')).to.equal(
      '.apply(b0, $diamonds:DATASET.count()) | .apply(b2, $diamonds:DATASET.sum($carat:NUMBER))'
    )
    expect(breakdown.byDataset['druid:diamonds2'].join(' | ')).to.equal(
      '.apply(b1, $diamonds2:DATASET.count())'
    )
    expect(breakdown.combine.toString()).to.equal('(($b0 * $b1) + $b2)')

  it "breakdown two datasets correctly (and de-duplicates expression)", ->
    ex = Expression.parse('$diamonds.count() * $diamonds2.sum($carat) + $diamonds.count()')

    ex = ex.referenceCheck(context)
    breakdown = ex.breakdownByDataset('b')
    expect(breakdown.byDataset).to.have.keys('druid:diamonds', 'druid:diamonds2')
    expect(breakdown.byDataset['druid:diamonds'].join(' | ')).to.equal(
      '.apply(b0, $diamonds:DATASET.count())'
    )
    expect(breakdown.byDataset['druid:diamonds2'].join(' | ')).to.equal(
      '.apply(b1, $diamonds2:DATASET.sum($carat:NUMBER))'
    )
    expect(breakdown.combine.toString()).to.equal('(($b0 * $b1) + $b0)')
