module Core {
  export function getType(value: any): string {
    var typeofValue = typeof value;
    if (typeofValue === 'object') {
      if (value === null) {
        return 'NULL';
      } else if (value.toISOString) {
        return 'TIME';
      } else {
        var type = value.constructor.type;
        if (!type) {
          if (Expression.isExpression(value)) {
            throw new Error("expression used as datum value " + value.toString());
          } else {
            throw new Error("can not have an object without a type: " + JSON.stringify(value));
          }
        }
        if (type === 'SET') {
          type += '/' + value.setType;
        }
        return type;
      }
    } else {
      if (typeofValue !== 'boolean' && typeofValue !== 'number' && typeofValue !== 'string') {
        throw new TypeError('unsupported JS type ' + typeofValue);
      }
      return typeofValue.toUpperCase();
    }
  }

  export function getTypeFull(value: any): any {
    var type = getType(value);
    return type === 'DATASET' ? value.getType() : type;
  }

  export function valueFromJS(v: any, type: string = null): any {
    if (v == null) {
      return null;
    } else if (Array.isArray(v)) {
      return NativeDataset.fromJS({
        source: 'native',
        data: v
      })
    } else if (typeof v === 'object') {
      switch (type || v.type) {
        case 'NUMBER':
          var n = Number(v.value);
          if (isNaN(n)) throw new Error("bad number value '" + String(v.value) + "'");
          return n;

        case 'NUMBER_RANGE':
          return NumberRange.fromJS(v);

        case 'TIME':
          return type ? v : new Date(v.value);

        case 'TIME_RANGE':
          return TimeRange.fromJS(v);

        case 'SHAPE':
          return Shape.fromJS(v);

        case 'SET':
          return Set.fromJS(v);

        default:
          if (v.toISOString) {
            return v; // Allow native date
          } else {
            throw new Error('can not have an object without a `type` as a datum value');
          }
      }
    } else if (typeof v === 'string' && type === 'TIME') {
      return new Date(v);
    }
    return v;
  }

  export function valueToJS(v: any): any {
    if (v == null) {
      return null;
    } else {
      var typeofV = typeof v;
      if (typeofV === 'object') {
        if (v.toISOString) {
          return v;
        } else {
          return v.toJS();
        }
      } else if (typeofV === 'number' && !isFinite(v)) {
        return String(v)
      }
    }
    return v;
  }

  export function valueToJSInlineType(v: any): any {
    if (v == null) {
      return null;
    } else {
      var typeofV = typeof v;
      if (typeofV === 'object') {
        if (v.toISOString) {
          return { type: 'TIME', value: v };
        } else {
          var js = v.toJS();
          if (!Array.isArray(js)) {
            js.type = v.constructor.type;
          }
          return js;
        }
      } else if (typeofV === 'number' && !isFinite(v)) {
        return { type: 'NUMBER', value: String(v) };
      }
    }
    return v;
  }

  // Remote stuff

  export function datumHasRemote(datum: Datum): boolean {
    for (var applyName in datum) {
      var applyValue = datum[applyName];
      if (applyName === '$def') {
        for (var defName in applyValue) {
          var defValue = applyValue[defName];
          if (defValue instanceof Dataset && defValue.hasRemote()) return true;
        }
      } else if (applyValue instanceof Dataset && applyValue.hasRemote()) {
        return true;
      }
    }
    return false;
  }

  export interface Capability {
    (ex: Expression): boolean;
  }

  export interface FilterCapabilities {
    canIs?: Capability;
    canAnd?: Capability;
    canOr?: Capability;
    canNot?: Capability;
  }

  export interface ApplyCombineCapabilities {
    canSum?: Capability;
    canMin?: Capability;
    canMax?: Capability;
    canGroup?: Capability;
  }

  export interface SplitCapabilities {
    canSelect?: ApplyCombineCapabilities;
    canTotal?: ApplyCombineCapabilities;
    canSplit?: ApplyCombineCapabilities;
  }

  export interface DatastoreQuery {
    query: any;
    post: (result: any) => Q.Promise<any>;
  }
}