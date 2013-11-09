{ expect } = require("chai")

WallTime = require('walltime-js')
if not WallTime.rules
  tzData = require("../../node_modules/walltime-js/client/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

chronology = require('../../build/chronology')

describe "chronology", ->
  tz = "America/Los_Angeles"

  describe "basic periods", ->
    it "moves seconds", ->
      dates = [
        new Date("2012-11-04T00:00:00-07:00")
        new Date("2012-11-04T00:00:03-07:00")
        new Date("2012-11-04T00:00:06-07:00")
        new Date("2012-11-04T00:00:09-07:00")
        new Date("2012-11-04T00:00:12-07:00")
      ]
      expect(chronology.second.move(dates[i - 1], tz, 3)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "moves minutes", ->
      dates = [
        new Date("2012-11-04T00:00:00-07:00")
        new Date("2012-11-04T00:03:00-07:00")
        new Date("2012-11-04T00:06:00-07:00")
        new Date("2012-11-04T00:09:00-07:00")
        new Date("2012-11-04T00:12:00-07:00")
      ]
      expect(chronology.minute.move(dates[i - 1], tz, 3)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "floors hour correctly", ->
      expect(chronology.hour.floor(new Date("2012-11-04T00:30:00-07:00"), tz)).to.deep
                            .equal(new Date("2012-11-04T00:00:00-07:00"))

      expect(chronology.hour.floor(new Date("2012-11-04T01:30:00-07:00"), tz)).to.deep
                            .equal(new Date("2012-11-04T01:00:00-07:00"))

      expect(chronology.hour.floor(new Date("2012-11-04T01:30:00-08:00"), tz)).to.deep
                            .equal(new Date("2012-11-04T01:00:00-08:00"))

      expect(chronology.hour.floor(new Date("2012-11-04T02:30:00-08:00"), tz)).to.deep
                            .equal(new Date("2012-11-04T02:00:00-08:00"))

      expect(chronology.hour.floor(new Date("2012-11-04T03:30:00-08:00"), tz)).to.deep
                            .equal(new Date("2012-11-04T03:00:00-08:00"))


    it "moves hour over DST", ->
      dates = [
        new Date("2012-11-04T00:00:00-07:00")
        new Date("2012-11-04T01:00:00-07:00")
        new Date("2012-11-04T01:00:00-08:00")
        new Date("2012-11-04T02:00:00-08:00")
        new Date("2012-11-04T03:00:00-08:00")
      ]
      expect(chronology.hour.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "moves day over DST", ->
      dates = [
        new Date("2012-11-03T00:00:00-07:00")
        new Date("2012-11-04T00:00:00-07:00")
        new Date("2012-11-05T00:00:00-08:00")
        new Date("2012-11-06T00:00:00-08:00")
      ]
      expect(chronology.day.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "moves week over DST", ->
      dates = [
        new Date("2012-10-29T00:00:00-07:00")
        new Date("2012-11-05T00:00:00-08:00")
        new Date("2012-11-12T00:00:00-08:00")
        new Date("2012-11-19T00:00:00-08:00")
      ]
      expect(chronology.week.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "moves month over DST", ->
      dates = [
        new Date("2012-11-01T00:00:00-07:00")
        new Date("2012-12-01T00:00:00-08:00")
        new Date("2013-01-01T00:00:00-08:00")
        new Date("2013-02-01T00:00:00-08:00")
      ]
      expect(chronology.month.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

    it "moves year", ->
      dates = [
        new Date("2010-01-01T00:00:00-08:00")
        new Date("2011-01-01T00:00:00-08:00")
        new Date("2012-01-01T00:00:00-08:00")
        new Date("2013-01-01T00:00:00-08:00")
      ]
      expect(chronology.year.move(dates[i - 1], tz, 1)).to.deep.equal(dates[i]) for i in [1...dates.length]

  describe "#durationMove", ->
    it "throws error if invalid duration", ->
      expect(->
        chronology.durationMove('')
      ).to.throw(Error, "Can not parse duration ''")

      expect(->
        chronology.durationMove('P00')
      ).to.throw(Error, "Can not parse duration 'P00'")

    it "throws error if empty duration", ->
      expect(->
        chronology.durationMove('P')
      ).to.throw(Error, "Must be a non zero duration")

      expect(->
        chronology.durationMove('PT')
      ).to.throw(Error, "Must be a non zero duration")

    it "throws error if empty duration with zeros", ->
      expect(->
        chronology.durationMove('P0W')
      ).to.throw(Error, "Must be a non zero duration")

      expect(->
        chronology.durationMove('P0Y0MT0H0M0S')
      ).to.throw(Error, "Must be a non zero duration")

    it "works for weeks", ->
      move1w = chronology.durationMove('P1W')
      expect(move1w(new Date("2012-10-29T00:00:00-07:00"), tz)).to.deep
             .equal(new Date("2012-11-05T00:00:00-08:00"))

      move1w = chronology.durationMove('P1W')
      expect(move1w(new Date("2012-10-29T00:00:00-07:00"), tz, 2)).to.deep
             .equal(new Date("2012-11-12T00:00:00-08:00"))

      move2w = chronology.durationMove('P2W')
      expect(move2w(new Date("2012-10-29T05:16:17-07:00"), tz)).to.deep
             .equal(new Date("2012-11-12T05:16:17-08:00"))

    it "works for general complex case", ->
      moveComplex = chronology.durationMove('P1Y2M3DT4H5M6S')
      expect(moveComplex(new Date("2012-01-01T00:00:00-08:00"), tz)).to.deep
                  .equal(new Date("2013-03-04T04:05:06-08:00"))





