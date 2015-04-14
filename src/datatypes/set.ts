module Facet {
  export interface SetValue {
    setType: string;
    elements: Lookup<any>;
  }

  export interface SetJS {
    setType: string;
    elements: Array<any>;
  }

  function dateString(date: Date): string {
    return date.toISOString();
  }

  function hashFromJS(xs: Array<string>, setType: string): Lookup<any> {
    var keyFn: (v: any) => string = setType === 'TIME' ? dateString : String;
    var hash: Lookup<any> = Object.create(null);
    for (var i = 0; i < xs.length; i++) {
      var x = valueFromJS(xs[i], setType);
      hash[keyFn(x)] = x;
    }
    return hash;
  }

  function hashToValues(hash: Lookup<any>): Array<any> {
    return Object.keys(hash).sort().map((k) => hash[k]);
  }

  function guessSetType(thing: any): string {
    var typeofThing = typeof thing;
    switch (typeofThing) {
      case 'boolean':
      case 'string':
      case 'number':
        return typeofThing.toUpperCase();

      default:
        if (thing.toISOString) return 'TIME';
        throw new Error("Could not guess the setType of the set. Please specify explicit setType");
    }
  }

  function unifyElements(elements: Lookup<Range<any>>): Lookup<Range<any>> {
    var newElements: Lookup<Range<any>> = Object.create(null);
    for (var k in elements) {
      var accumulator = elements[k];
      var newElementsKeys = Object.keys(newElements);
      for (var i = 0; i < newElementsKeys.length; i++) {
        var newElementsKey = newElementsKeys[i];
        var newElement = newElements[newElementsKey];
        var unionElement = accumulator.union(newElement);
        if (unionElement) {
          accumulator = unionElement;
          delete newElements[newElementsKey];
        }
      }
      newElements[accumulator.toString()] = accumulator;
    }
    return newElements;
  }

  function intersectElements(elements1: Lookup<Range<any>>, elements2: Lookup<Range<any>>): Lookup<Range<any>> {
    var newElements: Lookup<Range<any>> = Object.create(null);
    for (var k1 in elements1) {
      var element1 = elements1[k1];
      for (var k2 in elements2) {
        var element2 = elements2[k2];
        var intersect = element1.intersect(element2);
        if (intersect) newElements[intersect.toString()] = intersect;
      }
    }
    return newElements;
  }

  var check: ImmutableClass<SetValue, SetJS>;
  export class Set implements ImmutableInstance<SetValue, SetJS> {
    static type = 'SET';

    static isSet(candidate: any): boolean {
      return isInstanceOf(candidate, Set);
    }

    static fromJS(parameters: Array<any>): Set;
    static fromJS(parameters: SetJS): Set;
    static fromJS(parameters: any): Set {
      if (Array.isArray(parameters)) {
        parameters = { elements: parameters };
      }
      if (typeof parameters !== "object") {
        throw new Error("unrecognizable set");
      }
      var setType = parameters.setType;
      if (!setType) {
        setType = guessSetType(parameters.elements[0]);
      }
      return new Set({
        setType: setType,
        elements: hashFromJS(parameters.elements, parameters.setType)
      });
    }

    public setType: string;
    public elements: Lookup<any>;

    constructor(parameters: SetValue) {
      var setType = parameters.setType;
      this.setType = setType;

      var elements = parameters.elements;
      if (setType === 'NUMBER_RANGE' || setType === 'TIME_RANGE') {
        elements = unifyElements(elements);
      }
      this.elements = elements;
    }

    public valueOf(): SetValue {
      return {
        setType: this.setType,
        elements: this.elements
      };
    }

    public getValues(): any[] {
      return hashToValues(this.elements);
    }

    public toJS(): SetJS {
      return {
        setType: this.setType,
        elements: this.getValues().map(valueToJS)
      };
    }

    public toJSON(): SetJS {
      return this.toJS();
    }

    public toString(): string {
      return 'SET_' + this.setType + '(' + Object.keys(this.elements).length + ')';
    }

    public equals(other: Set): boolean {
      return Set.isSet(other) &&
        this.setType === other.setType &&
        Object.keys(this.elements).sort().join('') === Object.keys(other.elements).sort().join('');
    }

    public empty(): boolean {
      return this.toJS().elements.length === 0;
    }

    public union(other: Set): Set {
      if (this.setType !== other.setType) {
        throw new TypeError("can not union sets of different types");
      }

      var thisValues = this.elements;
      var otherValues = other.elements;
      var newValues: Lookup<any> = {};

      for (var k in thisValues) {
        if (!hasOwnProperty(thisValues, k)) continue;
        newValues[k] = thisValues[k];
      }

      for (var k in otherValues) {
        if (!hasOwnProperty(otherValues, k)) continue;
        newValues[k] = otherValues[k];
      }

      return new Set({
        setType: this.setType,
        elements: newValues
      });
    }

    public intersect(other: Set): Set {
      var setType = this.setType;
      if (this.setType !== other.setType) {
        throw new TypeError("can not intersect sets of different types");
      }

      var thisValues = this.elements;
      var otherValues = other.elements;
      var newValues: Lookup<any>;

      if (setType === 'NUMBER_RANGE' || setType === 'TIME_RANGE') {
        newValues = intersectElements(thisValues, otherValues);
      } else {
        newValues = Object.create(null);
        for (var k in thisValues) {
          if (hasOwnProperty(thisValues, k) && hasOwnProperty(otherValues, k)) {
            newValues[k] = thisValues[k];
          }
        }
      }

      return new Set({
        setType: this.setType,
        elements: newValues
      });
    }

    public contains(value: any): boolean {
      return hasOwnProperty(this.elements, String(value));
    }

    public containsWithin(value: any): boolean {
      var elements = this.elements;
      for (var k in elements) {
        if (!hasOwnProperty(elements, k)) continue;
        if ((<NumberRange>elements[k]).contains(value)) return true;
      }
      return false;
    }

    public add(value: any): Set {
      var elements = this.elements;
      var newValues: Lookup<any> = {};
      newValues[String(value)] = value;

      for (var k in elements) {
        if (!hasOwnProperty(elements, k)) continue;
        newValues[k] = elements[k];
      }

      return new Set({
        setType: this.setType,
        elements: newValues
      });
    }

    public label(name: string): Dataset {
      return new NativeDataset({
        source: 'native',
        key: name,
        data: this.getValues().map((v) => {
          var datum: Datum = {};
          datum[name] = v;
          return datum
        })
      });
    }

  }
  check = Set;
}
