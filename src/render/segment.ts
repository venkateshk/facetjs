var Interval;

Interval = require("./interval");

class Segment {
  constructor(public parent, prop, public splits) {
    var key, value;
    for (key in prop) {
      value = prop[key];
      if (Array.isArray(value)) {
        prop[key] = Interval.fromArray(value);
      }
    }

    this.prop = prop;
    this.scale = {};
  }

  public getProp(propName) {
    if (this.prop.hasOwnProperty(propName)) {
      return this.prop[propName];
    } else {
      if (!this.parent) {
        throw new Error("No such prop '" + propName + "'");
      }
      return this.parent.getProp(propName);
    }
  }

  public getScale(scaleName) {
    if (this.scale.hasOwnProperty(scaleName)) {
      return this.scale[scaleName];
    } else {
      if (!this.parent) {
        throw new Error("No such scale '" + scaleName + "'");
      }
      return this.parent.getScale(scaleName);
    }
  }

  public getDescription() {
    var description, propName, propValue, s, scaleName, _ref, _ref1;
    description = ["prop values:"];
    _ref = this.prop;
    for (propName in _ref) {
      propValue = _ref[propName];
      description.push("  " + propName + ": " + (String(propValue)));
    }

    if (this.splits) {
      description.push("", "(has " + this.splits.length + " splits)");
    }

    description.push("", "defined scales:");
    _ref1 = this.scale;
    for (scaleName in _ref1) {
      s = _ref1[scaleName];
      description.push("  " + scaleName);
    }

    return description.join("\n");
  }
}

module.exports = Segment;
