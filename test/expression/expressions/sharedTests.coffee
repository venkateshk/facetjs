{ expect } = require("chai")

exports.complexityIs = (expectedComplexity) ->
  describe '#getComplexty()', ->
    it 'gets the complexity correctly', ->
      expect(@expression.getComplexity()).to.equal(expectedComplexity)
