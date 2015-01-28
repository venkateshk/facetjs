{ expect } = require("chai")

module.exports = (expectedComplexity) ->
  describe '#getComplexty()', ->
    it 'gets the complexity correctly', -> expect(@expression.getComplexity()).to.equal(expectedComplexity)
