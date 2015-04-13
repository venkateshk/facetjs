module Facet {
  export interface TimeRangeValue {
    start: Date;
    end: Date;
    bounds?: string;
  }

  export interface TimeRangeJS {
    start: Date | string;
    end: Date | string;
    bounds?: string;
  }

  function toDate(date: any, name: string): Date {
    if (typeof date === "undefined" || date === null) throw new TypeError(`timeRange must have a ${name}`);
    if (typeof date === 'string' || typeof date === 'number') date = new Date(date);
    if (!date.getDay) throw new TypeError(`timeRange must have a ${name} that is a Date`);
    return date;
  }

  function dateToIntervalPart(date: Date): string {
    return date.toISOString()
      .replace('Z', '')
      .replace('.000', '')
      .replace(/:00$/, '')
      .replace(/:00$/, '')
      .replace(/T00$/, '');
  }

  var check: ImmutableClass<TimeRangeValue, TimeRangeJS>;
  export class TimeRange extends Range<Date> implements ImmutableInstance<TimeRangeValue, TimeRangeJS> {
    static type = 'TIME_RANGE';

    static isTimeRange(candidate: any): boolean {
      return isInstanceOf(candidate, TimeRange);
    }

    static timeBucket(date: Date, duration: Duration, timezone: Timezone): TimeRange {
      if (!date) return null;
      var start = duration.floor(date, timezone);
      return new TimeRange({
        start: start,
        end: duration.move(start, timezone, 1),
        bounds: Range.DEFAULT_BOUNDS
      });
    }

    static fromTimes(a: Date, b: Date): TimeRange {
      return new TimeRange({
        start: smaller(a, b),
        end: larger(a, b),
        bounds: Range.DEFAULT_BOUNDS
      })
    }

    static fromJS(parameters: TimeRangeJS): TimeRange {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable timeRange");
      }
      return new TimeRange({
        start: toDate(parameters.start, 'start'),
        end: toDate(parameters.end, 'end'),
        bounds: parameters.bounds
      });
    }

    constructor(parameters: TimeRangeValue) {
      super(parameters.start, parameters.end, parameters.bounds);
    }

    protected _zeroEndpoint(): Date {
      return new Date(0);
    }

    protected _endpointEqual(a: Date, b: Date): boolean {
      return a.valueOf() === b.valueOf();
    }

    protected _endpointToString(a: Date): string {
      return a.toISOString();
    }

    public valueOf(): TimeRangeValue {
      return {
        start: this.start,
        end: this.end,
        bounds: this.bounds
      };
    }

    public toJS(): TimeRangeJS {
      var js: TimeRangeJS = {
        start: this.start,
        end: this.end
      };
      if (this.bounds !== Range.DEFAULT_BOUNDS) js.bounds = this.bounds;
      return js;
    }

    public toJSON(): TimeRangeJS {
      return this.toJS();
    }

    public equals(other: TimeRange): boolean {
      return TimeRange.isTimeRange(other) && this._equalsHelper(other);
    }

    public toInterval(): string {
      return dateToIntervalPart(this.start) + "/" + dateToIntervalPart(this.end);
    }
  }
  check = TimeRange;
}
