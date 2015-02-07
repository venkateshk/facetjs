declare var module: {
  exports: any;
};

if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports.Datatypes = Datatypes;
  module.exports.Expressions = Expressions;
  module.exports.Actions = Actions;
}
