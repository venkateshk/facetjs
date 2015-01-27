facet() // [{}]
  .container('div.example')

  .def("Diamonds", facet(sqlDriverClient).filter("$color = 'D'"))
  // [{ Diamonds: <Dataset> }]

  .def('Stage', Shape.rectangle(800, 600))
  // [{ Diamonds: <Dataset>, stage: { type: 'shape', shape: 'rectangle', width: 800, height: 600 } }]

  .def('Count', '$Diamonds.count()')
  // [{ Diamonds: <Dataset>, stage: '<shape>', Count: 2342 }]

  .def('VerticalScale', Scale.linear())

  .def('ColorScale', Scale.color())

  .def('Cuts',
    facet("Diamonds").split("$cut", 'Cut')
      // [
      //   {
      //     Cut: 'good'
      //   }
      //   {
      //     Cut: 'v good'
      //   }
      //   {
      //     Cut: 'ideal'
      //   }
      // ]

      .def('Diamonds', facet('^Diamonds').filter('$cut = $^Cut'))
      // [
      //   {
      //     Cut: 'good'
      //     Diamonds: <dataset cut=good>
      //   }
      //   {
      //     Cut: 'v good'
      //     Diamonds: <dataset cut=v good>
      //   }
      //   {
      //     Cut: 'ideal'
      //     Diamonds: <dataset cut=ideal>
      //   }
      // ]

      .def('Count', facet('diamonds').count())
      .def('AvgPrice', '$diamonds.sum("price") / $diamonds.count()')
      .sort('AvgPrice', 'descending')
      .limit(10)
      .def('AccAvgPrice', 'AvgPrice')
      .def('stage', Layout.horizontal('$stage', { gap: 3 }))
      .train('verticalScale', 'domain', '$AvgPrice')
      .train('verticalScale', 'range', '$stage.height')
      .train('color', 'domain', '$Cut')
      .def('maxPrice', '$self.max($price)')
      .def('barStage', function(d) {
        return Transform.margin(d.stage, {
          bottom: 0,
          height: d.verticalScale(d.AvgPrice)
        })
      })
      .def('barStage1', Transform.margin('stage', {
        bottom: 0,
        height: '$verticalScale($AvgPrice)'
      }))
      .def('barStage2', "stage.margin(bottom=0, height=$verticalScale($AvgPrice))")
      .render(Mark.box('barStage', {
        type: 'box',
        fill: '#f0f0f0',
        stroke: use('color')
      }))
      .def('pointStage', Transform.margin('barStage', {
        bottom: 6
      }))
      .render(Mark.label('$pointStage', {
        text: '$Cut',
        color: '$color',
        anchor: 'middle',
        baseline: 'bottom'
      })) // Used without name
    )
    .compute();

