{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.core

describe "planner", ->
  it "works in advanced case", ->
    context = {
      diamonds: Dataset.fromJS({
        source: 'remote'
        driver: () -> null # NoOp
        attributes: {
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          price: { type: 'NUMBER' }
        }
      })
    }

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

    expect(ex.generatePlan(context).toJS()).to.deep.equal([

    ])

    # -----------------------
    ###

    e1 = facet()
      .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
      .apply('Count', facet('diamonds').count())
      .apply('TotalPrice', facet('diamonds').sum('$price'))

    d1 = e1.compute()

    e2 = facet(d1)
      .apply('Cuts',
        facet("diamonds").group("$cut").label('Cut')
          .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
          .apply('Count', facet('diamonds').count())
          .sort('$Count', 'descending')
          .limit(2)
      )

    d2 = e2.compute()

    e3 = facet(d2)
      .apply('Cuts',
        facet('Cuts')
          .apply('Carats',
            facet("diamonds").group(facet("carat").numberBucket(0.25)).label('Carat')
              .def('diamonds', facet('diamonds').filter(facet("carat").numberBucket(0.25).is('$^Carat')))
              .apply('Count', facet('diamonds').count())
              // Or not
              //.sort('$Count', 'descending')
              //.limit(3)
          )
      )

    d3 = e3.compute()

    e4 = facet(d3)
      .apply('Cuts',
        facet('Cuts')
          .apply('Carats',
            facet('Carats')
              .sort('$Count', 'descending')
              .limit(3)
          )
      )
    ###
