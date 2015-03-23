var druidRequester = require('facetjs-druid-requester').druidRequester;
var facet = require('../../build/facet');
var Dataset = facet.core.Dataset;

var druidPass = druidRequester({
  host: '10.153.211.100' // Where ever your Druid may be
});

// ----------------------------------

var context = {
  wiki: Dataset.fromJS({
    source: 'druid',
    dataSource: 'wikipedia_editstream',  // The datasource name in Druid
    timeAttribute: 'time',  // Druid's anonymous time attribute will be called 'time'
    forceInterval: true,  // Do not issue queries on unbounded time (no interval set)
    approximate: true,  // Allow approximate results, Druid is not as awesome of you stick to the exact stuff
    requester: druidPass
  })
};

var ex = facet()
  .def("wiki",
    facet('wiki').filter(facet("time").in({
      start: new Date("2013-02-26T00:00:00Z"),
      end: new Date("2013-02-27T00:00:00Z")
    }))
  )
  .apply('Count', facet('wiki').count())
  .apply('TotalAdded', '$wiki.sum($added)')
  .apply('Pages',
    facet('wiki').split('$page', 'Page')
      .apply('Count', facet('wiki').count())
      .sort('$Count', 'descending')
      .limit(6)
  );

ex.compute(context).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(JSON.stringify(data.toJS(), null, 2));
}).done();

// ----------------------------------

/*
Output:
[
  {
    "Count": 573775,
    "TotalAdded": 124184252,
    "Page": [
      {
        "Page": "Wikipedia:Vandalismusmeldung",
        "Count": 177
      },
      {
        "Page": "Wikipedia:Administrator_intervention_against_vandalism",
        "Count": 124
      },
      {
        "Page": "Wikipedia:Auskunft",
        "Count": 124
      },
      {
        "Page": "Wikipedia:Löschkandidaten/26._Februar_2013",
        "Count": 88
      },
      {
        "Page": "Wikipedia:Reference_desk/Science",
        "Count": 88
      },
      {
        "Page": "Wikipedia:Administrators'_noticeboard",
        "Count": 87
      }
    ]
  }
]
*/
