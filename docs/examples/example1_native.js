facet = require('../../build/facet');
legacyDriver = facet.core.legacyDriver;
nativeDriver = facet.legacy.nativeDriver;

diamondsData = require('../../data/diamonds.js');
diamondDriver = legacyDriver(nativeDriver(diamondsData));

// ----------------------------------

var context = {
  diamonds: diamondDriver
};

ex = facet()
  .def("diamonds", facet('diamonds').filter(facet("color").is('D')))
  .apply('Count', facet('diamonds').count())
  .apply('TotalPrice', '$diamonds.sum($price)');

ex.compute(context).then(function(data) {
  // Log the data while converting it to a readable standard
  console.log(JSON.stringify(data.toJS(), null, 2));
}).done();

// ----------------------------------

/*
Output:
[
  {
    "Count": 6775,
    "TotalPrice": 21476439
  }
]
*/
