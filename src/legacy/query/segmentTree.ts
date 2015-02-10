module Legacy {
  export interface Prop {
    [propName: string]: any; //PropValue;
  }

  function cleanProp(prop: Prop): void {
    for (var key in prop) {
      var value: any = prop[key];
      if (key[0] === "_") {
        delete prop[key];
      } else if (Array.isArray(value) && typeof value[0] === "string") {
        value[0] = new Date(<any>(value[0]));
        value[1] = new Date(<any>(value[1]));
      }
    }
  }

  export interface SegmentTreeJS {
    prop?: Prop;
    splits?: SegmentTreeJS[];
    loading?: boolean;
    isOthers?: boolean;
  }

  export interface SegmentTreeValue {
    parent?: SegmentTree;
    prop?: Prop;
    splits?: SegmentTree[];
    loading?: boolean;
    isOthers?: boolean;
  }

  var check: ImmutableClass<SegmentTreeValue, SegmentTreeJS>;
  export class SegmentTree implements ImmutableInstance<SegmentTreeValue, SegmentTreeJS> {
    static isPropValueEqual(pv1: any, pv2: any) {
      if (Array.isArray(pv1) && pv1.length === 2) {
        if (!(Array.isArray(pv2) && pv2.length === 2)) return false;
        return pv1[0].valueOf() === pv2[0].valueOf() && pv1[1].valueOf() === pv2[1].valueOf();
      } else {
        return pv1 === pv2;
      }
    }

    static isPropValueIn(propValue: any, propValueList: any[]) {
      var isPropValueEqual = SegmentTree.isPropValueEqual;
      return propValueList.some((pv) => isPropValueEqual(propValue, pv));
    }

    static isPropEqual(prop1: Prop, prop2: Prop) {
      var propNames = Object.keys(prop1);
      if (propNames.length !== Object.keys(prop2).length) return false;
      var isPropValueEqual = SegmentTree.isPropValueEqual;
      for (var i = 0; i < propNames.length; i++) {
        var propName = propNames[i];
        if (!isPropValueEqual(prop1[propName], prop2[propName])) return false;
      }
      return true;
    }


    static isSegmentTree(candidate: any): boolean {
      return isInstanceOf(candidate, SegmentTree);
    }

    static fromJS(parameters: SegmentTreeJS, parent: SegmentTree = null): SegmentTree {
      var newSegmentTree = new SegmentTree({
        parent: parent,
        prop: parameters.prop,
        loading: parameters.loading,
        isOthers: parameters.isOthers
      });
      if (parameters.splits) {
        newSegmentTree.splits = parameters.splits.map((st) => SegmentTree.fromJS(st, newSegmentTree));
      }
      return newSegmentTree;
    }

    public parent: SegmentTree;
    public prop: Prop;
    public splits: SegmentTree[];
    public loading: boolean;
    public meta: any;
    public isOthers: boolean;

    constructor(parameters: SegmentTreeValue, meta: any = null) {
      var prop = parameters.prop;
      var splits = parameters.splits;
      var loading = parameters.loading;
      var isOthers = parameters.isOthers;
      this.parent = parameters.parent || null;
      this.meta = meta;
      if (prop) {
        this.setProps(prop);
      } else if (splits) {
        throw new Error("can not initialize splits without prop");
      }
      if (splits) this.splits = splits;
      if (loading) this.loading = true;
      if (isOthers) this.isOthers = true;
    }

    public valueOf() {
      var spec: SegmentTreeValue = {};
      if (this.parent) {
        spec.parent = this.parent;
      }
      if (this.prop) {
        spec.prop = this.prop;
      }
      if (this.splits) {
        spec.splits = this.splits;
      }
      if (this.loading) {
        spec.loading = true;
      }
      if (this.isOthers) {
        spec.isOthers = true;
      }
      return spec;
    }

    public toJS() {
      var spec: SegmentTreeJS = {};
      if (this.prop) {
        spec.prop = this.prop;
      }
      if (this.splits) {
        spec.splits = this.splits.map((split) => split.toJS());
      }
      if (this.loading) {
        spec.loading = true;
      }
      if (this.isOthers) {
        spec.isOthers = true;
      }
      return spec;
    }

    public toJSON() {
      return this.toJS();
    }

    public equals(other: SegmentTree) {
      return SegmentTree.isSegmentTree(other) &&
        SegmentTree.isPropEqual(this.prop, other.prop) &&
        this.loading === other.loading &&
        this.isOthers === other.isOthers &&
        Boolean(this.splits) === Boolean(other.splits);
      // ToDo: fill in split check
    }

    public toString(): string {
      return JSON.stringify(this.prop); // ToDo: improve this
    }

    public selfClean() {
      for (var k in this) {
        if (!this.hasOwnProperty(k)) continue;
        if (k[0] === "_") {
          delete (<any>this)[k];
        }
      }

      if (this.splits) {
        this.splits.forEach((split) => split.selfClean());
      }

      return this;
    }

    public setProps(prop: Prop) {
      cleanProp(prop);
      this.prop = prop;
      return this;
    }

    public setSplits(splits: SegmentTree[]) {
      splits.forEach((split) => split.parent = this);
      this.splits = splits;
      return this;
    }

    public markLoading() {
      this.loading = true;
      return this;
    }

    public hasLoading() {
      if (this.loading) {
        return true;
      }
      if (this.splits) {
        var splits = this.splits;
        for (var i = 0; i < splits.length; i++) {
          var segment = splits[i];
          if (segment.hasLoading()) {
            return true;
          }
        }
      }
      return false;
    }

    public hasProp(propName: string): boolean {
      if (!this.prop) {
        return false;
      }
      return this.prop.hasOwnProperty(propName);
    }

    public getProp(propName: string): any {
      var segmentProp = this.prop;
      if (!segmentProp) {
        return null;
      }
      if (this.hasProp(propName)) {
        return segmentProp[propName];
      }
      if (this.parent) {
        return this.parent.getProp(propName);
      } else {
        return null;
      }
    }

    public getParentDepth() {
      var depth = 0;
      var node = this;
      while (node = node.parent) {
        depth++;
      }
      return depth;
    }

    public getMaxDepth() {
      var maxDepth = 1;
      if (this.splits) {
        this.splits.forEach((segment) => maxDepth = Math.max(maxDepth, segment.getMaxDepth() + 1));
      }
      return maxDepth;
    }

    public specToMaxDepth(maxDepth: number) {
      var spec: SegmentTreeJS = {};
      if (this.prop) {
        spec.prop = this.prop;
      }
      if (this.splits && maxDepth > 1) {
        var newMaxDepth = maxDepth - 1;
        spec.splits = this.splits.map((split) => split.specToMaxDepth(newMaxDepth));
      }
      if (this.loading) {
        spec.loading = true;
      }
      if (this.isOthers) {
        spec.isOthers = true;
      }
      return spec;
    }

    public trimToMaxDepth(maxDepth: number) {
      if (maxDepth < 1) return null;
      var spec = this.specToMaxDepth(maxDepth);
      return SegmentTree.fromJS(spec);
    }

    public isSubTreeOf(subTree: SegmentTree) {
      while (subTree) {
        if (this.prop === subTree.prop) {
          return true;
        }
        subTree = subTree.parent;
      }
      return false;
    }

    private _flattenHelper(order: string, result: SegmentTree[]) {
      if (order === "preorder" || !this.splits) {
        result.push(this);
      }

      if (this.splits) {
        this.splits.forEach((split) => split._flattenHelper(order, result));
      }

      if (order === "postorder") {
        result.push(this);
      }
    }

    public flatten(order: string = "preorder") {
      if (order !== "preorder" && order !== "postorder" && order !== "none") {
        throw new TypeError("order must be on of preorder, postorder, or none");
      }
      var result: SegmentTree[];
      this._flattenHelper(order, result = []);
      return result;
    }

    public hasOthers(): boolean {
      return this.splits.some(function (segmentTree) {
        return segmentTree.isOthers;
      });
    }
  }
  check = SegmentTree;
}