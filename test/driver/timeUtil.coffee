{ expect } = require("chai")

WallTime = require('walltime-js')
if not WallTime.rules
  tzData = require("../../node_modules/walltime-js/client/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

timeUtil = require('../../build/timeUtil')

describe "timeUtil", ->
  tz = "America/Los_Angeles"

  it "floors hour correctly", ->
    expect(timeUtil.hour.floor(new Date("2012-11-04T00:30:00-07:00"), tz)).to.deep.equal(new Date("2012-11-04T00:00:00.000-07:00"))
    expect(timeUtil.hour.floor(new Date("2012-11-04T01:30:00-07:00"), tz)).to.deep.equal(new Date("2012-11-04T01:00:00.000-07:00"))
    expect(timeUtil.hour.floor(new Date("2012-11-04T01:30:00-08:00"), tz)).to.deep.equal(new Date("2012-11-04T01:00:00.000-08:00"))
    expect(timeUtil.hour.floor(new Date("2012-11-04T02:30:00-08:00"), tz)).to.deep.equal(new Date("2012-11-04T02:00:00.000-08:00"))
    expect(timeUtil.hour.floor(new Date("2012-11-04T03:30:00-08:00"), tz)).to.deep.equal(new Date("2012-11-04T03:00:00.000-08:00"))

  it "moves hour over DST", ->
    dates = [
      new Date("2012-11-04T00:00:00.000-07:00")
      new Date("2012-11-04T01:00:00.000-07:00")
      new Date("2012-11-04T01:00:00.000-08:00")
      new Date("2012-11-04T02:00:00.000-08:00")
      new Date("2012-11-04T03:00:00.000-08:00")
    ]
    expect(timeUtil.hour.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

  it "moves day over DST", ->
    dates = [
      new Date("2012-11-03T00:00:00.000-07:00")
      new Date("2012-11-04T00:00:00.000-07:00")
      new Date("2012-11-05T00:00:00.000-08:00")
      new Date("2012-11-06T00:00:00.000-08:00")
    ]
    expect(timeUtil.day.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

  it "moves week over DST", ->
    dates = [
      new Date("2012-10-29T00:00:00.000-07:00")
      new Date("2012-11-05T00:00:00.000-08:00")
      new Date("2012-11-12T00:00:00.000-08:00")
      new Date("2012-11-19T00:00:00.000-08:00")
    ]
    expect(timeUtil.week.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

  it "moves month over DST", ->
    dates = [
      new Date("2012-11-01T00:00:00.000-07:00")
      new Date("2012-12-01T00:00:00.000-08:00")
      new Date("2013-01-01T00:00:00.000-08:00")
      new Date("2013-02-01T00:00:00.000-08:00")
    ]
    expect(timeUtil.month.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]




