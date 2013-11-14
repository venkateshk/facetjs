{ expect } = require("chai")

WallTime = require('walltime-js')
if not WallTime.rules
  tzData = require("../../node_modules/walltime-js/client/walltime-data.js")
  WallTime.init(tzData.rules, tzData.zones)

chronology = require('../../build/chronology')
{ Duration } = chronology

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


  describe "Duration", ->
    it "throws error if invalid duration", ->
      expect(->
        new Duration('')
      ).to.throw(Error, "Can not parse duration ''")

      expect(->
        new Duration('P00')
      ).to.throw(Error, "Can not parse duration 'P00'")

    describe "#toString", ->
      it "gives back the correct string", ->
        durationStr = 'P3Y'
        expect(new Duration(durationStr).toString()).to.equal(durationStr)

        durationStr = 'P2W'
        expect(new Duration(durationStr).toString()).to.equal(durationStr)

        durationStr = 'PT5H'
        expect(new Duration(durationStr).toString()).to.equal(durationStr)

        durationStr = 'P3DT15H'
        expect(new Duration(durationStr).toString()).to.equal(durationStr)

      it "eliminates 0", ->
        expect(new Duration('P0DT15H').toString()).to.equal('PT15H')

    describe "construct from span", ->
      it "parses days over DST", ->
        expect(new Duration(
          new Date("2012-10-29T00:00:00-07:00")
          new Date("2012-11-05T00:00:00-08:00")
          tz
        ).toString()).to.equal('P7D')

        expect(new Duration(
          new Date("2012-10-29T00:00:00-07:00")
          new Date("2012-11-12T00:00:00-08:00")
          tz
        ).toString()).to.equal('P14D')

      it "parses complex case", ->
        expect(new Duration(
          new Date("2012-10-29T00:00:00-07:00")
          new Date(new Date("2012-11-05T00:00:00-08:00") - 1000)
          tz
        ).toString()).to.equal('P6DT24H59M59S')

        expect(new Duration(
          new Date("2012-01-01T00:00:00-08:00")
          new Date("2013-03-04T04:05:06-08:00")
          tz
        ).toString()).to.equal('P1Y2M3DT4H5M6S')

    describe "#floor", ->
      it "throws error if complex duration", ->
        expect(->
          new Duration('PT2H').floor(new Date(), tz)
        ).to.throw(Error, "Can not floor on a complex duration")

        expect(->
          new Duration('P1Y2D').floor(new Date(), tz)
        ).to.throw(Error, "Can not floor on a complex duration")

        expect(->
          new Duration('P3DT15H').floor(new Date(), tz)
        ).to.throw(Error, "Can not floor on a complex duration")

      it "works for year", ->
        p1y = new Duration('P1Y')
        expect(p1y.floor(new Date("2013-09-29T01:02:03.456-07:00"), tz)).to.deep
                  .equal(new Date("2013-01-01T00:00:00.000-08:00"))

      it "works for week", ->
        p1w = new Duration('P1W')
        expect(p1w.floor(new Date("2013-09-29T01:02:03.456-07:00"), tz)).to.deep
                  .equal(new Date("2013-09-29T00:00:00.000-07:00"))

        expect(p1w.floor(new Date("2013-10-03T01:02:03.456-07:00"), tz)).to.deep
                  .equal(new Date("2013-09-29T00:00:00.000-07:00"))

      it "works for milliseconds", ->
        p1ms = new Duration('P')
        expect(p1ms.floor(new Date("2013-09-29T01:02:03.456-07:00"), tz)).to.deep
                   .equal(new Date("2013-09-29T01:02:03.456-07:00"))

        p1ms = new Duration('P0YT0H')
        expect(p1ms.floor(new Date("2013-09-29T01:02:03.456-07:00"), tz)).to.deep
                   .equal(new Date("2013-09-29T01:02:03.456-07:00"))


    describe "#move", ->
      it "throws error if empty duration", ->
        expect(->
          new Duration('P').move(new Date(), tz)
        ).to.throw(Error, "Must be a non zero duration")

        expect(->
          new Duration('PT').move(new Date(), tz)
        ).to.throw(Error, "Must be a non zero duration")

      it "throws error if empty duration with zeros", ->
        expect(->
          new Duration('P0W').move(new Date(), tz)
        ).to.throw(Error, "Must be a non zero duration")

        expect(->
          new Duration('P0Y0MT0H0M0S').move(new Date(), tz)
        ).to.throw(Error, "Must be a non zero duration")

      it "works for weeks", ->
        p1w = new Duration('P1W')
        expect(p1w.move(new Date("2012-10-29T00:00:00-07:00"), tz)).to.deep
                 .equal(new Date("2012-11-05T00:00:00-08:00"))

        p1w = new Duration('P1W')
        expect(p1w.move(new Date("2012-10-29T00:00:00-07:00"), tz, 2)).to.deep
                 .equal(new Date("2012-11-12T00:00:00-08:00"))

        p2w = new Duration('P2W')
        expect(p2w.move(new Date("2012-10-29T05:16:17-07:00"), tz)).to.deep
                 .equal(new Date("2012-11-12T05:16:17-08:00"))

      it "works for general complex case", ->
        pComplex = new Duration('P1Y2M3DT4H5M6S')
        expect(pComplex.move(new Date("2012-01-01T00:00:00-08:00"), tz)).to.deep
                      .equal(new Date("2013-03-04T04:05:06-08:00"))


    describe "#canonicalLength", ->
      it "gives back the correct canonicalLength", ->
        durationStr = 'P3Y'
        expect(new Duration(durationStr).canonicalLength()).to.equal(94608000000)

        durationStr = 'P2W'
        expect(new Duration(durationStr).canonicalLength()).to.equal(1209600000)

        durationStr = 'PT5H'
        expect(new Duration(durationStr).canonicalLength()).to.equal(18000000)

        durationStr = 'P3DT15H'
        expect(new Duration(durationStr).canonicalLength()).to.equal(313200000)

