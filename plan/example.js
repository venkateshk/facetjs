facet(someDriverReference)
  .filter("$color = 'D'")
  .apply("priceOver2", "$price/2")
  .compute(true)


facet() // [{}]
  .apply("Diamonds",
    facet(someDriverReference)
      .filter("$color = 'D'")
      .apply("priceOver2", "$price/2")
  )
  // [{ Diamonds: <Dataset> }]

  .apply('Count', '$Diamonds.count()')
  // [{ diamonds: <Dataset>, Count: 2342 }]

  //.apply('TotalPrice', '$diamonds.sum($priceOver2 * 2)')
  .apply('TotalPrice', facet('Diamonds').sum('$priceOver2 * 2'))
  // [{ diamonds: <Dataset>, Count: 2342, TotalPrice: 234534 }]

  .apply('Cuts',
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

      .apply('Diamonds', facet('Diamonds').filter('$cut = $^Cut'))
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

      .apply('Count', facet('Diamonds').count())
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
      .apply('AvgPrice', '$diamonds.sum($price) / $diamonds.count()')
      .sort('$Time', 'ascending')
      .apply('somethingElse', '$diamonds.sum($x)')
  )
    .compute()