var facet = require('../../build/facet');
var Dataset = facet.core.Dataset;

var diamondsData = require('../../data/diamonds.js');

// ----------------------------------

var context = {
  diamonds: Dataset.fromJS({
    source: 'native',
    data: diamondsData
  })
};

var ex = facet()
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
