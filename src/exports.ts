if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  var moduleExports: any = Facet.facet;
  for (var key in Facet) {
    if (!hasOwnProperty(Facet, key)) continue;
    moduleExports[key] = (<any>Facet)[key];
  }
  moduleExports.helper = Facet.Helper;
  moduleExports.legacy = Facet.Legacy;

  module.exports = moduleExports;
}
