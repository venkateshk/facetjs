declare var module: {
  exports: any;
};

if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = Facet;
}
