facet(someDriverReference)
  .filter("$color = 'D'")
  .def("priceOver2", "$price/2")
  .compute(true)


facet() // [{}]
  .def("Diamonds",
    facet(someDriverReference)
      .filter("$color = 'D'")
      .def("priceOver2", "$price/2")
  )
  // [{ Diamonds: <Dataset> }]

  .def('Count', '$Diamonds.count()')
  // [{ diamonds: <Dataset>, Count: 2342 }]

  //.def('TotalPrice', '$diamonds.sum($priceOver2 * 2)')
  .def('TotalPrice', facet('Diamonds').sum('$priceOver2 * 2'))
  // [{ diamonds: <Dataset>, Count: 2342, TotalPrice: 234534 }]

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

      .def('Diamonds', facet('Diamonds').filter('$cut = $^Cut'))
      // [
      //   {
      //     Cut: 'good'
      //     Diamonds: <dataset cut = good>
      //   }
      //   {
      //     Cut: 'v good'
      //     Diamonds: <dataset cut = v good>
      //   }
      //   {
      //     Cut: 'ideal'
      //     Diamonds: <dataset cut = ideal>
      //   }
      // ]

      .def('Count', facet('Diamonds').count())
      // [
      //   {
      //     Cut: 'good'
      //     diamonds: <dataset cut = good>
      //     Count: 213
      //   }
      //   {
      //     Cut: 'v good'
      //     diamonds: <dataset cut = v good>
      //     Count: 21
      //   }
      //   {
      //     Cut: 'ideal'
      //     diamonds: <dataset cut = ideal>
      //     Count: 13
      //   }
      // ]
      .def('AvgPrice', '$diamonds.sum($price) / $diamonds.count()')
      .sort('$Time', 'ascending')
      .def('somthingElse', '$diamonds.sum($x)')
  )
    .compute()