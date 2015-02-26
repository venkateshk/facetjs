var druidRequester = require('facetjs-druid-requester').druidRequester;
var facet = require('../../build/facet');
var legacyDriver = facet.core.legacyDriver;
var druidDriver = facet.legacy.druidDriver;

var druidPass = druidRequester({
  host: '10.153.211.100' // Where ever your Druid may be
});

var wikiDriver = legacyDriver(druidDriver({
  requester: druidPass,
  dataSource: 'wikipedia_editstream',
  timeAttribute: 'time',
  forceInterval: true,
  approximate: true
}));

// ----------------------------------

var context = {
  wiki: wikiDriver
};

var ex = facet()
  .def("wiki",
    facet('wiki').filter(facet("time").in({
      start: new Date("2013-02-26T00:00:00Z"),
      end: new Date("2013-02-27T00:00:00Z")
    }).and(facet('language').is('en')))
  )
  .apply('Count', facet('wiki').count())
  .apply('TotalAdded', '$wiki.sum($added)');

ex.compute(context).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(JSON.stringify(data.toJS(), null, 2));
}).done();

// ----------------------------------

/*
Output:
[
  {
    "Count": 308675,
    "TotalAdded": 41412583
  }
]
*/
