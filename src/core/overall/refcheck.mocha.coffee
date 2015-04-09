{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet

describe "reference check", ->

  context = {
    diamonds: Dataset.fromJS([
      { color: 'A', cut: 'great', carat: 1.1, price: 300 }
    ])
  }

  describe "errors", ->
    it "fails to resolve a variable that does not exist", ->
      ex = facet()
        .def('num', 5)
        .apply('subData',
          facet()
            .apply('x', '$num + 1')
            .apply('y', '$foo * 2')
        )

      expect(->
        ex.referenceCheck({})
      ).to.throw('could not resolve $foo')

    it "fails to resolve a variable that does not exist (in scope)", ->
      ex = facet()
        .def('num', 5)
        .apply('subData',
          facet()
            .apply('x', '$num + 1')
            .apply('y', '$^x * 2')
        )

      expect(->
        ex.referenceCheck({})
      ).to.throw('could not resolve $^x')

    it "fails to when a variable goes too deep", ->
      ex = facet()
        .def('num', 5)
        .apply('subData',
          facet()
            .apply('x', '$num + 1')
            .apply('y', '$^^^x * 2')
        )

      expect(->
        ex.referenceCheck({ x: 5 })
      ).to.throw('went too deep on $^^^x')

    it "fails when discovering that the types mismatch", ->
      ex = facet()
        .def('str', 'Hello')
        .apply('subData',
          facet()
            .apply('x', '$str + 1')
        )

      expect(->
        ex.referenceCheck({ str: 'Hello World' })
      ).to.throw('add must have an operand of type NUMBER at position 0')

    it "fails when discovering that the types mismatch via label", ->
      ex = facet()
        .def("diamonds", facet("diamonds").filter(facet('color').is('D')))
        .apply('Cuts',
          facet("diamonds").group("$cut").label('Cut')
            .apply('TotalPrice', '$Cut * 10')
        )

      expect(->
        ex.referenceCheck(context)
      ).to.throw('multiply must have an operand of type NUMBER at position 0')


  describe "resolves", ->
    it "works in a basic case", ->
      ex = facet()
        .def('num', 5)
        .apply('subData',
          facet()
            .apply('x', '$num + 1')
            .apply('y', '$x * 2')
        )

      expect(ex.referenceCheck({}).toJS()).to.deep.equal(
        facet()
          .def('num', 5)
          .apply('subData',
            facet()
              .apply('x', '$^num:NUMBER + 1')
              .apply('y', '$x:NUMBER * 2')
          )
          .toJS()
      )

    it "works from context", ->
      ex = facet('diamonds')
        .def('priceOver2', '$price / 2')

      expect(ex.referenceCheck(context).toJS()).to.deep.equal(
        facet('diamonds:DATASET')
          .def('priceOver2', '$price:NUMBER / 2')
          .toJS()
      )

    it "a split", ->
      ex = facet()
        .def("diamonds", facet("diamonds").filter(facet('color').is('D')))
        .apply('Count', '$diamonds.count()')
        .apply('TotalPrice', '$diamonds.sum($price)')
        .apply('Cuts',
          facet("diamonds").group("$cut").label('Cut')
            .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
            .apply('Count', '$diamonds.count()')
            .apply('TotalPrice', '$diamonds.sum($price)')
            .apply('AvgPrice', '$TotalPrice / $Count')
            .sort('$AvgPrice', 'descending')
            .limit(10)
        )

      expect(ex.referenceCheck(context).toJS()).to.deep.equal(
        facet()
          .def("diamonds", facet("^diamonds:DATASET").filter(facet('color:STRING').is('D')))
          .apply('Count', '$diamonds:DATASET.count()')
          .apply('TotalPrice', '$diamonds:DATASET.sum($price:NUMBER)')
          .apply('Cuts',
            facet("diamonds:DATASET").group("$cut:STRING").label('Cut')
              .def('diamonds', facet('^diamonds:DATASET').filter(facet('cut:STRING').is('$^Cut:STRING')))
              .apply('Count', '$diamonds:DATASET.count()')
              .apply('TotalPrice', '$diamonds:DATASET.sum($price:NUMBER)')
              .apply('AvgPrice', '$TotalPrice:NUMBER / $Count:NUMBER')
              .sort('$AvgPrice:NUMBER', 'descending')
              .limit(10)
          )
          .toJS()
      )

    it "two splits", ->
      ex = facet()
        .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
        .apply('Count', facet('diamonds').count())
        .apply('TotalPrice', facet('diamonds').sum('$price'))
        .apply('Cuts',
          facet("diamonds").group("$cut").label('Cut')
            .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
            .apply('Count', facet('diamonds').count())
            .sort('$Count', 'descending')
            .limit(2)
            .apply('Carats',
              facet("diamonds").group(facet("carat").numberBucket(0.25)).label('Carat')
                .def('diamonds', facet('diamonds').filter(facet("carat").numberBucket(0.25).is('$^Carat')))
                .apply('Count', facet('diamonds').count())
                .sort('$Count', 'descending')
                .limit(3)
            )
        )

      expect(ex.referenceCheck(context).toJS()).to.deep.equal(
        facet()
          .def("diamonds", facet('^diamonds:DATASET').filter(facet("color:STRING").is('D')))
          .apply('Count', facet('diamonds:DATASET').count())
          .apply('TotalPrice', facet('diamonds:DATASET').sum('$price:NUMBER'))
          .apply('Cuts',
            facet("diamonds:DATASET").group("$cut:STRING").label('Cut')
              .def('diamonds', facet('^diamonds:DATASET').filter(facet('cut:STRING').is('$^Cut:STRING')))
              .apply('Count', facet('diamonds:DATASET').count())
              .sort('$Count:NUMBER', 'descending')
              .limit(2)
              .apply('Carats',
                facet("diamonds:DATASET").group(facet("carat:NUMBER").numberBucket(0.25)).label('Carat')
                  .def('diamonds', facet('^diamonds:DATASET').filter(facet("carat:NUMBER").numberBucket(0.25).is('$^Carat:NUMBER_RANGE')))
                  .apply('Count', facet('diamonds:DATASET').count())
                  .sort('$Count:NUMBER', 'descending')
                  .limit(3)
              )
          )
          .toJS()
      )
