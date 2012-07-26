interval = {
  start: date(2011, 01, 01).time(00, 00)
  end:   date(2011, 01, 02).time(00, 00)
}

# where
filters = [
  {
    k: 'make'
    v: ['Honda']
  }
  {
    k: 'color'
    v: ['red', 'blue']
  }
]

pivot = [
  {
    dimension: 'model'
    top: 10
  }
    {
      dimension: '$time'
      gran: 'hour'
    }
]

data = mmx.data {
  interval: interval
  filters: filters
  pivot: pivot
}

data ==> [{
  make: 'Honda'
  color: 'red'
  revenue: 120000
  volume: 100

  $breakdown: {
    dimension: 'model'
    values: [
      {
        make: 'Honda'
        color: 'red'
        model: 'Accord'
        revenue: 10000
        volume: 10

        $breakdown: {
          dimension: '$time'
          values:
        }
      }
      {
        make: 'Honda'
        color: 'red'
        model: 'Civic'
        revenue: 7000
        volume: 8
      }
    ]
  }
}]