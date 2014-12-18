"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

module.exports = {
  slice: (sort, limit) => ({
    method: "slice",
    sort: sort,
    limit: limit
  })
};
