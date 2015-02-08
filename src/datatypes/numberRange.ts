module Core {
  export interface NumberRangeValue {
    start: number;
    end: number;
  }

  export interface NumberRangeJS {
    start: any;
    end: any;
  }

  function numberToJS(n: number): any {
    return isFinite(n) ? n : String(n);
  }

  var check: ImmutableClass<NumberRangeValue, NumberRangeJS>;
  export class NumberRange implements ImmutableInstance<NumberRangeValue, NumberRangeJS> {
    static type = 'NUMBER_RANGE';

    static isNumberRange(candidate: any): boolean {
      return isInstanceOf(candidate, NumberRange);
    }

    static fromJS(parameters: NumberRangeJS): NumberRange {
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable numberRange");
      }
      return new NumberRange({
        start: Number(parameters.start),
        end: Number(parameters.end)
      });
    }

    public start: number;
    public end: number;

    constructor(parameters: NumberRangeJS) {
      this.start = parameters.start;
      this.end = parameters.end;
      if (isNaN(this.start)) throw new TypeError('`start` must be a number');
      if (isNaN(this.end)) throw new TypeError('`end` must be a number');
    }

    public valueOf(): NumberRangeValue {
      return {
        start: this.start,
        end: this.end
      };
    }

    public toJS(): NumberRangeJS {
      return {
        start: numberToJS(this.start),
        end: numberToJS(this.end)
      };
    }

    public toJSON(): NumberRangeJS {
      return this.toJS();
    }

    public toString(): string {
      return "[" + this.start + ',' + this.end + ")";
    }

    public equals(other: NumberRange): boolean {
      return NumberRange.isNumberRange(other) &&
        this.start === other.start &&
        this.end === other.end;
    }

    public union(other: NumberRange): NumberRange {
      if ((this.start < other.start && (this.end <= other.start)) ||
        (other.start < this.start) && (other.end <= this.start)) {
        return null;
      }
      var start = Math.min(this.start, other.start);
      var end = Math.max(this.end, other.end);

      return new NumberRange({start: start, end: end});
    }

    public intersect(other: NumberRange): NumberRange {
      if ((this.start < other.start && (this.end <= other.start)) ||
        (other.start < this.start) && (other.end <= this.start)) {
        return null;
      }
      var start = Math.max(this.start, other.start);
      var end = Math.min(this.end, other.end);

      return new NumberRange({start: start, end: end});
    }

    public test(val: Number): boolean {
      return this.start <= val && val < this.end;
    }
  }
  check = NumberRange;
}
