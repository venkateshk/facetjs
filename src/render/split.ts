module.exports = {
  identity: (attribute) => ({
    bucket: "identity",
    attribute: attribute
  }),
  continuous: (attribute, size, offset: any = 0) => {
    if (!size) {
      throw new Error("continuous split must have " + size);
    }
    return {
      bucket: "continuous",
      attribute: attribute,
      size: size,
      offset: offset
    };
  },
  timePeriod: (attribute, period, timezone) => {
    if (period !== "PT1S" && period !== "PT1M" && period !== "PT1H" && period !== "P1D" && period !== "P1W") {
      throw new Error("invalid period '" + period + "'");
    }
    return {
      bucket: "timePeriod",
      attribute: attribute,
      period: period,
      timezone: timezone
    };
  },
  tuple: (...splits) => {
    if (!splits.length) {
      throw new Error("can not have an empty tuple");
    }
    return {
      bucket: "tuple",
      splits: splits
    };
  }
};
