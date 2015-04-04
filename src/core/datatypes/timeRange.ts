module Core {
  export interface TimeRangeValue {
    start: Date;
    end: Date;
  }

  export interface TimeRangeJS {
    start: any;
    end: any;
  }

  function toDate(date: any, name: string): Date {
    if (typeof date === "undefined" || date === null) throw new TypeError('timeRange must have a `' + name + '`');
    if (typeof date === 'string' || typeof date === 'number') date = new Date(date);
    if (!date.getDay) throw new TypeError('timeRange must have a `' + name + '` that is a Date');
    return date;
  }

  function dateToIntervalPart(date: Date): string {
    return date.toISOString()
      .replace("Z", "")
      .replace(".000", "")
      .replace(/:00$/, "")
      .replace(/:00$/, "")
      .replace(/T00$/, "");
  }

  var check: ImmutableClass<TimeRangeValue, TimeRangeJS>;
  export class TimeRange implements ImmutableInstance<TimeRangeValue, TimeRangeJS> {
    static type = 'TIME_RANGE';

    static isTimeRange(candidate: any): boolean {
      return isInstanceOf(candidate, TimeRange);
    }

    static fromDate(date: Date, duration: Duration, timezone: Timezone): TimeRange {
      if (!date) return null;
      var start = duration.floor(date, timezone);
      return new TimeRange({
        start: start,
        end: duration.move(start, timezone, 1)
      });
    }

    static fromJS(parameters: TimeRangeJS): TimeRange {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable timeRange");
      }
      return new TimeRange({
        start: toDate(parameters.start, 'start'),
        end: toDate(parameters.end, 'end')
      });
    }

    public start: Date;
    public end: Date;

    constructor(parameters: TimeRangeJS) {
      this.start = parameters.start;
      this.end = parameters.end;
    }

    public valueOf(): TimeRangeValue {
      return {
        start: this.start,
        end: this.end
      };
    }

    public toJS(): TimeRangeJS {
      return {
        start: this.start,
        end: this.end
      };
    }

    public toJSON(): TimeRangeJS {
      return this.toJS();
    }

    public toString(): string {
      return "[" + this.start.toISOString() + ',' + this.end.toISOString() + ")";
    }

    public equals(other: TimeRange): boolean {
      return TimeRange.isTimeRange(other) &&
        this.start.valueOf() === other.start.valueOf() &&
        this.end.valueOf() === other.end.valueOf();
    }

    public toInterval(): string {
      return dateToIntervalPart(this.start) + "/" + dateToIntervalPart(this.end);
    }

    public union(other: TimeRange): TimeRange {
      if ((this.start < other.start && (this.end <= other.start)) ||
        (other.start < this.start) && (other.end <= this.start)) {
        return null;
      }
      var start = Math.min(this.start.valueOf(), other.start.valueOf());
      var end = Math.max(this.end.valueOf(), other.end.valueOf());

      return new TimeRange({start: new Date(start), end: new Date(end)});
    }

    public intersect(other: TimeRange): TimeRange {
      if ((this.start < other.start && (this.end <= other.start)) ||
        (other.start < this.start) && (other.end <= this.start)) {
        return null;
      }
      var start = Math.max(this.start.valueOf(), other.start.valueOf());
      var end = Math.min(this.end.valueOf(), other.end.valueOf());

      return new TimeRange({start: new Date(start), end: new Date(end)});
    }

    public contains(val: Date): boolean {
      return this.start.valueOf() <= val.valueOf() && val.valueOf() < this.end.valueOf();
    }
  }
  check = TimeRange;
}
