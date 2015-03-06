{ expect } = require("chai")

facet = require('../../../build/facet')
{ Expression, Dataset } = facet.core

describe "planner", ->
  it "works in advanced case", ->
    context = {
      diamonds: Dataset.fromJS({
        source: 'druid',
        dataSource: 'diamonds',
        timeAttribute: 'time',
        forceInterval: true,
        approximate: true,
        context: null
        attributes: {
          color: { type: 'STRING' }
          cut: { type: 'STRING' }
          carat: { type: 'STRING' }
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

    expect(ex.getExpressionBreakdown().map((e) -> e.toJS())).to.deep.equal([

      facet()
        .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
        .apply('Count', facet('diamonds').count())
        .apply('TotalPrice', facet('diamonds').sum('$price'))
    ,
      facet('next:DATASET')
        .apply('Cuts',
          facet("diamonds").group("$cut").label('Cut')
            .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
            .apply('Count', facet('diamonds').count())
            .sort('$Count', 'descending')
            .limit(2)
        )
    ,
      facet('next:DATASET')
        .apply('Cuts',
          facet('Cuts:DATASET')
            .apply('Carats',
              facet("diamonds").group(facet("carat").numberBucket(0.25)).label('Carat')
                .def('diamonds', facet('diamonds').filter(facet("carat").numberBucket(0.25).is('$^Carat')))
                .apply('Count', facet('diamonds').count())
                .sort('$Count', 'descending')
                .limit(3)
            )
        )

    ].map((e) -> e.toJS()))

    console.log("ex.simulateQueryPlan()", ex.simulateQueryPlan(context).map((q) -> JSON.stringify(q, null, 2)).join('\n------------------\n'));
