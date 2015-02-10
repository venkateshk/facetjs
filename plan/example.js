facet(someDriverReference)
  .filter("$color = 'D'")
  .apply("priceOver2", "$price/2")
  .compute(true)


facet() // [{}]
  .apply("DiamondsMain",
    facet(someDriverReference)
      .filter("$color = 'D'")
      .apply("priceOver2", "$price/2")
  )
  .apply("DiamondsCmp",
    facet(someDriverReference)
      .filter("$color = 'H'")
      .apply("priceOver2", "$price/2")
  )
  // [{ Diamonds: <Dataset> }]

  .apply('Count', '$DiamondsMain.count()')
  // [{ diamonds: <Dataset>, Count: 2342 }]

  //.apply('TotalPrice', '$diamonds.sum($priceOver2 * 2)')
  .apply('TotalPrice', facet('DiamondsMain').sum('$priceOver2 * 2'))
  // [{ diamonds: <Dataset>, Count: 2342, TotalPrice: 234534 }]

  .apply('Cuts',
    facet("DiamondsMain").split("$cut").union(facet("DiamondsCmp").split("$cut"))

      // Set(['good', 'v good', 'ideal', 'bad'])
      .label('Cut')

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

      .apply('DiamondsMain', facet('DiamondsMain').filter('$cut = $^Cut'))
      .apply('DiamondsCmp', facet('DiamondsCmp').filter('$cut = $^Cut'))
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

      .apply('Count', facet('DiamondsMain').count())
      .apply('CountCmp', facet('DiamondsCmp').count())
      .apply('CountDalta', '$Count - $CountCmp')

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


