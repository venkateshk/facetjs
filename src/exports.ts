if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = Core.facet;
  module.exports.core = Core;
  module.exports.extra = Extra;
  module.exports.legacy = Legacy;
}
