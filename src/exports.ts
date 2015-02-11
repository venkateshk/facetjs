declare var module: {
  exports: any;
};

if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = Core.facet;
  module.exports.core = Core;
  module.exports.legacy = Legacy;
}
