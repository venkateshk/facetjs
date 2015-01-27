myDiamonds = new Dataset([
  { "carat": 0.23, "cut": "Ideal",   "color": "E", "clarity": "SI2", "price": 326 },
  { "carat": 0.21, "cut": "Premium", "color": "E", "clarity": "SI1", "price": 326 },
  { "carat": 0.23, "cut": "Good",    "color": "E", "clarity": "VS1", "price": 328 }
]);

facet() // [{}]
  .def("diamonds",
    facet(myDiamonds)
      .def("priceOver2", "$price/2")
  )
  // [{
  //   diamonds: [
  //     { "carat": 0.23, "cut": "Ideal",   "color": "E", "clarity": "SI2", "price": 326, priceOver2: 163 },
  //     { "carat": 0.21, "cut": "Premium", "color": "E", "clarity": "SI1", "price": 326, priceOver2: 163 },
  //     { "carat": 0.23, "cut": "Good",    "color": "E", "clarity": "VS1", "price": 328, priceOver2: 164  }
  //   ]
  // }]

  .def('Count', '$diamonds.count()')
  // [{
  //   diamonds: [
  //     { "carat": 0.23, "cut": "Ideal",   "color": "E", "clarity": "SI2", "price": 326, priceOver2: 163 },
  //     { "carat": 0.21, "cut": "Premium", "color": "E", "clarity": "SI1", "price": 326, priceOver2: 163 },
  //     { "carat": 0.23, "cut": "Good",    "color": "E", "clarity": "VS1", "price": 328, priceOver2: 164  }
  //   ]
  //   Count: 3
  // }]

  .def('TotalPrice', facet('diamonds').sum('$priceOver2'))
  .def('TotalPrice', facet('diamonds').sum('$price * $carat'))
  // [{
  //   diamonds: [
  //     { "carat": 0.23, "cut": "Ideal",   "color": "E", "clarity": "SI2", "price": 326, priceOver2: 163 },
  //     { "carat": 0.21, "cut": "Premium", "color": "E", "clarity": "SI1", "price": 326, priceOver2: 163 },
  //     { "carat": 0.23, "cut": "Good",    "color": "E", "clarity": "VS1", "price": 328, priceOver2: 164  }
  //   ]
  //   Count: 3
  //   TotalPrice: 490
  // }]

  .def('Cuts',
    facet("diamonds").split("$cut", 'Cut')
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

      .def('diamonds', facet('diamonds').filter('$cut = $^Cut'))
      // [
      //   {
      //     Cut: 'good'
      //     diamonds: <dataset cut = good>
      //   }
      //   {
      //     Cut: 'v good'
      //     diamonds: <dataset cut = v good>
      //   }
      //   {
      //     Cut: 'ideal'
      //     diamonds: <dataset cut = ideal>
      //   }
      // ]

      .def('Count', facet('diamonds').count())
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
      .sort('$AvgPrice', 'descending')
      .limit(3)
      .def('somethingElse', '$diamonds.sum($x)')
  )
  .compute()