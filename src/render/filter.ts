"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

module.exports = {
  "true": () => ({
    type: "true"
  }),
  "false": () => ({
    type: "false"
  }),
  "is": (attribute, value) => ({
    type: "is",
    attribute: attribute,
    value: value
  }),
  "in": (attribute, values) => ({
    type: "in",
    attribute: attribute,
    values: values
  }),
  "contains": (attribute, value) => ({
    type: "contains",
    attribute: attribute,
    value: value
  }),
  "match": (attribute, expression) => ({
    type: "match",
    attribute: attribute,
    expression: expression
  }),
  "within": (attribute, range) => {
    if (!(Array.isArray(range) && range.length === 2)) {
      throw new TypeError("range must be an array of two things");
    }
    return {
      type: "within",
      attribute: attribute,
      range: range
    };
  },
  "not": (filter) => {
    if (typeof filter !== "object") {
      throw new TypeError("filter must be a filter object");
    }
    return {
      type: "not",
      filter: filter
    };
  },
  "and": (...filters) => {
    if (!filters.length) {
      throw new TypeError("must have some filters");
    }
    return {
      type: "and",
      filters: filters
    };
  },
  "or": (...filters) => {
    if (!filters.length) {
      throw new TypeError("must have some filters");
    }
    return {
      type: "or",
      filters: filters
    };
  }
};
