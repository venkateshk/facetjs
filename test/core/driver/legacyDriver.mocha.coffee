{ expect } = require("chai")

facet = require('../../../build/facet')
{ legacyDriver, legacyTranslator } = facet.core

describe "legacyDriver", ->
  ex = facet()
    .def("Diamonds", facet('SOME_DATA').filter(facet("color").is('D')))
    .apply('Count', facet('Diamonds').count())
    .apply('TotalPrice', facet('Diamonds').sum('$price'))
    .apply('Cuts',
      facet("Diamonds").group("$cut").label('Cut')
        .def('Diamonds', facet('Diamonds').filter(facet('cut').is('$^Cut')))
        .apply('Count', facet('Diamonds').count())
        .sort('$Count', 'descending')
        .limit(4)
#        .apply('Carat',
#          facet("Diamonds").group(facet("carat").numberBucket(0.1)).label('Carat')
#            .def('Diamonds', facet('Diamonds').filter(facet("carat").numberBucket(0.1).is('$^Carat')))
#            .apply('Count', facet('Diamonds').count())
#            .sort('$Count', 'descending')
#            .limit(5)
#        )
    )

  it "translates", ->
    expect(legacyTranslator(ex).toJS()).to.deep.equal([
      {
        "attribute": "color"
        "operation": "filter"
        "type": "is"
        "value": "D"
      }
      {
        "aggregate": "count"
        "name": "Count"
        "operation": "apply"
      }
      {
        "aggregate": "count"
        "name": "TotalPrice"
        "operation": "apply"
      }
      {
        "attribute": "cut"
        "bucket": "identity"
        "name": "Cut"
        "operation": "split"
      }
      {
        "aggregate": "count"
        "name": "Count"
        "operation": "apply"
      }
    ])
