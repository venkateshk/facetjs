facet = require('../../build/facet');
legacyDriver = facet.core.legacyDriver;
simpleDriver = facet.legacy.simpleDriver;

diamondsData = require('../../data/diamonds.js');
diamondDriver = legacyDriver(simpleDriver(diamondsData));

ex = facet()
  .def("diamonds", facet('diamonds')).filter(facet("color").is('D')))
  .apply('Count', facet('diamonds').count())
  .apply('TotalPrice', '$diamonds.sum($price)');
  //.apply('Cuts',
  //  facet("diamonds").split("$cut", 'Cut')
  //    .def('diamonds', facet('diamonds').filter(facet('cut').is('$^Cut')))
  //    .apply('Count', facet('diamonds').count())
  //    .sort('$Count', 'descending')
  //    .limit(2)
  //);

ex.compute({
  diamonds: diamondDriver
}).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(data.toJS());
}).done();
