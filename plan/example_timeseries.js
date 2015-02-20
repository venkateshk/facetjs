facet()
  // [{}]

  .apply("wiki",
    facet(wikipediaDriver)
      .filter("$language = 'en'")
  )
  // [{ wiki: { type: 'dataset' } }]

  .apply('Count', '$wiki.count()')
  // [{ wiki: { type: 'dataset' }, Count: 2342 }]

  .apply('Hours',
    facet("wiki").split("bucket($timestamp, PT1H, Etc/UTC)", 'TimeByHour')
    facet("wiki").split("$timestamp.bucket(PT1H, Etc/UTC)", 'TimeByHour')
    facet("wiki").split(facet("timestamp").bucket(PT1H, Etc/UTC), 'TimeByHour')
      // [
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T00:00:00Z', end: '2015-01-01T01:00:00Z' }
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T01:00:00Z', end: '2015-01-01T02:00:00Z' }
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T02:00:00Z', end: '2015-01-01T03:00:00Z' }
      //   }
      // ]
      .apply('wiki', facet('wiki').filter('$timestamp in $TimeByHour'))
      // [
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T00:00:00Z', end: '2015-01-01T01:00:00Z' }
      //     wiki: <dataset>
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T01:00:00Z', end: '2015-01-01T02:00:00Z' }
      //     wiki: <dataset>
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T02:00:00Z', end: '2015-01-01T03:00:00Z' }
      //     wiki: <dataset>
      //   }
      // ]
      .apply('Count', facet('wiki').count())
      // [
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T00:00:00Z', end: '2015-01-01T01:00:00Z' }
      //     wiki: <dataset>
      //     Count: 213
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T01:00:00Z', end: '2015-01-01T02:00:00Z' }
      //     wiki: <dataset>
      //     Count: 21
      //   }
      //   {
      //     TimeByHour: { type: 'timeRange', start: '2015-01-01T02:00:00Z', end: '2015-01-01T03:00:00Z' }
      //     wiki: <dataset>
      //     Count: 13
      //   }
      // ]
  )
  .compute()