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
  approximate: true
}));

ex = facet()
  .def("wiki", facet('wiki').filter(facet("language").is('en')))
  .apply('Count', facet('wiki').count())
  .apply('TotalAdded', '$wiki.sum($added)');

ex.compute({
  wiki: wikiDriver
}).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(data.toJS());
}).done();
