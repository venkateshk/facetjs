var druidRequesterFactory = require('facetjs-druid-requester').druidRequesterFactory;
var facet = require('../../build/facet');
var $ = facet.$;
var Dataset = facet.Dataset;

WallTime = require('chronology').WallTime;
if (!WallTime.rules) {
  tzData = require("chronology/lib/walltime/walltime-data.js");
  WallTime.init(tzData.rules, tzData.zones);
}

var druidRequester = druidRequesterFactory({
  host: '10.153.211.100' // Where ever your Druid may be
});

// ----------------------------------

druidRequester = facet.helper.verboseRequesterFactory({
  requester: druidRequester
});

var context = {
  wiki: Dataset.fromJS({
    source: 'druid',
    dataSource: 'wikipedia_editstream',  // The datasource name in Druid
    timeAttribute: 'time',  // Druid's anonymous time attribute will be called 'time'
    requester: druidRequester
  })
};

var ex = $()
  .def("wiki",
    $('wiki').filter($("time").in({
      start: new Date("2013-02-26T00:00:00Z"),
      end: new Date("2013-02-27T00:00:00Z")
    }))
  )
  .apply('Count', $('wiki').count())
  .apply('ByHour',
    $('wiki').split($("time").timeBucket('PT1H', 'Etc/UTC'), 'TimeByHour')
      .sort('$TimeByHour', 'ascending')
      .apply('Users',
        $('wiki').split('$user', 'User')
          .apply('Count', $('wiki').count())
          .sort('$Count', 'descending')
          .limit(3)
      )
  );

ex.compute(context).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(JSON.stringify(data.toJS(), null, 2));
}).done();

// ----------------------------------

/*
Output:

]
*/
