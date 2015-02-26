druidRequester = require('facetjs-druid-requester').druidRequester;
facet = require('../../build/facet');
legacyDriver = facet.core.legacyDriver;
druidDriver = facet.legacy.druidDriver;

druidPass = druidRequester({
  host: '10.153.211.100' // Where ever your Druid may be
});

wikiDriver = legacyDriver(druidDriver({
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

ex = facet()
  .def("wiki",
    facet('wiki').filter(facet("time").in({
      start: new Date("2013-02-26T00:00:00Z"),
      end: new Date("2013-02-27T00:00:00Z")
    }).and(facet('language').is('en')))
  )
  .def("wiki", facet('wiki').filter(facet("language").is('en')))
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
