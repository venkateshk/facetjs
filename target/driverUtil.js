(function() {
  var exports, rq;

  rq = function(module) {
    var moduleParts;
    if (typeof window === 'undefined') {
      return require(module);
    } else {
      moduleParts = module.split('/');
      return window[moduleParts[moduleParts.length - 1]];
    }
  };

  if (typeof exports === 'undefined') {
    exports = {};
  }

  exports.flatten = function(ar) {
    return Array.prototype.concat.apply([], ar);
  };

  exports.condenseQuery = function(query) {
    var cmd, condensed, curQuery, _i, _len;
    curQuery = {
      split: null,
      applies: [],
      combine: null
    };
    condensed = [];
    for (_i = 0, _len = query.length; _i < _len; _i++) {
      cmd = query[_i];
      switch (cmd.operation) {
        case 'split':
          condensed.push(curQuery);
          curQuery = {
            split: cmd,
            applies: [],
            combine: null
          };
          break;
        case 'apply':
          curQuery.applies.push(cmd);
          break;
        case 'combine':
          if (curQuery.combine) {
            throw new Error("Can not have more than one combine");
          }
          curQuery.combine = cmd;
          break;
        default:
          throw new Error("Unknown operation '" + cmd.operation + "'");
      }
    }
    condensed.push(curQuery);
    return condensed;
  };

  exports.cleanSegment = function(segment) {
    var key, prop;
    for (key in segment) {
      if (key[0] === '_') {
        delete segment[key];
      }
    }
    prop = segment.prop;
    for (key in prop) {
      if (key[0] === '_') {
        delete prop[key];
      }
    }
  };

  if (typeof module === 'undefined') {
    window['driverUtil'] = exports;
  } else {
    module.exports = exports;
  }

}).call(this);
