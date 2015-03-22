module Core {
  export interface PostProcess {
    (result: any): NativeDataset;
  }

  export interface QueryAndPostProcess<T> {
    query: T;
    postProcess: PostProcess;
  }

  export interface IntrospectPostProcess {
    (result: any): Lookup<AttributeInfo>;
  }

  export interface IntrospectQueryAndPostProcess<T> {
    query: T;
    postProcess: IntrospectPostProcess;
  }

  function getSampleValue(valueType: string, ex: Expression): any {
    switch (valueType) {
      case 'BOOLEAN':
        return true;

      case 'NUMBER':
        return 4;

      case 'NUMBER_RANGE':
        if (ex instanceof NumberBucketExpression) {
          return new NumberRange({ start: ex.offset, end: ex.offset + ex.size });
        } else {
          return new NumberRange({ start: 0, end: 1 });
        }

      case 'TIME':
        return new Date('2015-03-14T00:00:00');

      case 'TIME_RANGE':
        if (ex instanceof TimeBucketExpression) {
          var start = ex.duration.floor(new Date('2015-03-14T00:00:00'), ex.timezone);
          return new TimeRange({ start: start, end: ex.duration.move(start, ex.timezone, 1) });
        } else {
          return new TimeRange({ start: new Date('2015-03-14T00:00:00'), end: new Date('2015-03-15T00:00:00') });
        }

      case 'STRING':
        if (ex instanceof RefExpression) {
          return 'some_' + ex.name;
        } else {
          return 'something';
        }

      default:
        throw new Error("unsupported simulation on: " + valueType);
    }
  }

  export class RemoteDataset extends Dataset {
    static type = 'DATASET';

    static jsToValue(parameters: any): DatasetValue {
      var value = Dataset.jsToValue(parameters);
      if (parameters.requester) value.requester = parameters.requester;
      value.filter = parameters.filter || Expression.TRUE;
      return value;
    }

    public requester: Requester.FacetRequester<any>;
    public mode: string; // raw, total, split (potential aggregate mode)
    public derivedAttributes: ApplyAction[];
    public filter: Expression;
    public split: Expression;
    public label: string;
    public defs: DefAction[];
    public applies: ApplyAction[];
    public sort: SortAction;
    public sortOrigin: string;
    public limit: LimitAction;
    public havingFilter: Expression;
    //public fullJoin: RemoteDataset; // ToDo: maybe a good idea to have chain joins
    //public leftJoin: RemoteDataset;

    constructor(parameters: DatasetValue, dummy: Dummy = null) {
      super(parameters, dummyObject);
      this.requester = parameters.requester;
      this.mode = parameters.mode || 'raw';
      this.derivedAttributes = parameters.derivedAttributes || [];
      this.filter = parameters.filter || Expression.TRUE;
      this.split = parameters.split;
      this.label = parameters.label;
      this.defs = parameters.defs;
      this.applies = parameters.applies;
      this.sort = parameters.sort;
      this.sortOrigin = parameters.sortOrigin;
      this.limit = parameters.limit;
      this.havingFilter = parameters.havingFilter;

      if (this.mode !== 'raw') {
        this.defs = this.defs || [];
        this.applies = this.applies || [];

        if (this.mode === 'split') {
          if (!this.split) throw new Error('must have split in split mode');
          if (!this.label) throw new Error('must have label in split mode');
          this.havingFilter = this.havingFilter || Expression.TRUE;
        }
      }
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      if (this.requester) {
        value.requester = this.requester;
      }
      value.mode = this.mode;
      value.derivedAttributes = this.derivedAttributes;
      value.filter = this.filter;
      if (this.split) {
        value.split = this.split;
        value.label = this.label;
      }
      if (this.defs) {
        value.defs = this.defs;
      }
      if (this.applies) {
        value.applies = this.applies;
      }
      if (this.sort) {
        value.sort = this.sort;
        value.sortOrigin = this.sortOrigin;
      }
      if (this.limit) {
        value.limit = this.limit;
      }
      if (this.havingFilter) {
        value.havingFilter = this.havingFilter;
      }
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      if (this.requester) {
        js.requester = this.requester;
      }
      if (!this.filter.equals(Expression.TRUE)) {
        js.filter = this.filter.toJS();
      }
      return js;
    }

    public toString(): string {
      switch (this.mode) {
        case 'raw':
          return `RemoteRaw(${this.filter.toString()})`;

        case 'total':
          return `RemoteTotal(${this.applies.length})`;

        case 'split':
          return `RemoteSplit(${this.applies.length})`;

        default :
          return 'Remote()';
      }

    }

    public equals(other: RemoteDataset): boolean {
      return super.equals(other) &&
        this.filter.equals(other.filter);
    }

    public hasRemote(): boolean {
      return true;
    }

    public getRemoteDatasets(): RemoteDataset[] {
      return [this];
    }

    // -----------------

    public canHandleFilter(ex: Expression): boolean {
      throw new Error("must implement canHandleFilter");
    }

    public canHandleTotal(): boolean {
      throw new Error("must implement canHandleTotal");
    }

    public canHandleSplit(ex: Expression): boolean {
      throw new Error("must implement canHandleSplit");
    }

    public canHandleSort(sortAction: SortAction): boolean {
      throw new Error("must implement canHandleSort");
    }

    public canHandleLimit(limitAction: LimitAction): boolean {
      throw new Error("must implement canHandleLimit");
    }

    public canHandleHavingFilter(ex: Expression): boolean {
      throw new Error("must implement canHandleHavingFilter");
    }

    // -----------------

    public makeTotal(): RemoteDataset {
      if (this.mode !== 'raw') return null; // Can only split on 'raw' datasets
      if (!this.canHandleTotal()) return null;

      var value = this.valueOf();
      value.mode = 'total';

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public addSplit(splitExpression: Expression, label: string): RemoteDataset {
      if (this.mode !== 'raw') return null; // Can only split on 'raw' datasets
      if (!this.canHandleSplit(splitExpression)) return null;

      var value = this.valueOf();
      value.mode = 'split';
      value.split = splitExpression;
      value.label = label;

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    public addAction(action: Action): RemoteDataset {
      var value = this.valueOf();
      var expression = action.expression;

      if (action instanceof FilterAction) {
        if (!expression.resolved()) return null;

        switch (this.mode) {
          case 'raw':
            if (!this.canHandleFilter(expression)) return null;
            value.filter = value.filter.and(expression).simplify();
            break;

          case 'split':
            if (!this.canHandleHavingFilter(expression)) return null;
            value.havingFilter = value.havingFilter.and(expression).simplify();
            break;

          default:
            return null; // can not add filter in total mode
        }

      } else if (action instanceof DefAction) {
        if (expression.type !== 'DATASET') return null;

        switch (this.mode) {
          case 'total':
            if (expression instanceof LiteralExpression) {
              var otherDataset: RemoteDataset = expression.value;
              value.derivedAttributes = otherDataset.derivedAttributes;
              value.filter = otherDataset.filter;
              value.defs = value.defs.concat(action);
            } else {
              return null;
            }
            break;

          case 'split':
            // Expect it to be .def('myData', facet('myData').filter(split = ^label)
            var defExpression = action.expression;
            if (defExpression instanceof ActionsExpression &&
              defExpression.actions.length === 1 &&
              defExpression.actions[0].action === 'filter' &&
              defExpression.actions[0].expression.equals(
                this.split.is(new RefExpression({ op: 'ref', name: '^' + this.label, type: this.split.type })))
            ) {
              value.defs = value.defs.concat(action);

            } else {
              return null;
            }
            break;

          default:
            return null; // can not add filter in total mode
        }

      } else if (action instanceof ApplyAction) {
        if (expression.type !== 'NUMBER') return null;

        if (this.mode === 'raw') {
          value.derivedAttributes = value.derivedAttributes.concat(action);
        } else {
          if (action.name === this.label) return null;
          value.applies = value.applies.concat(action);
        }

      } else if (action instanceof SortAction) {
        if (!this.canHandleSort(action)) return null;
        value.sort = action;

      } else if (action instanceof LimitAction) {
        if (!this.canHandleLimit(action)) return null;
        value.limit = action;

      } else {
        return null;
      }

      return <RemoteDataset>(new (Dataset.classMap[this.source])(value));
    }

    // -----------------

    public simulate(): NativeDataset {
      var datum: Datum = {};

      if (this.mode === 'raw') {
        var attributes = this.attributes;
        for (var attributeName in attributes) {
          if (!attributes.hasOwnProperty(attributeName)) continue;
          datum[attributeName] = getSampleValue(attributes[attributeName].type, null);
        }
      } else {
        if (this.mode === 'split') {
          datum[this.label] = getSampleValue(this.split.type, this.split);
        }

        var applies = this.applies;
        for (var i = 0; i < applies.length; i++) {
          var apply = applies[i];
          datum[apply.name] = getSampleValue(apply.expression.type, apply.expression);
        }
      }

      return new NativeDataset({
        source: 'native',
        data: [datum]
      });
    }

    public getQueryAndPostProcess(): QueryAndPostProcess<any> {
      throw new Error("can not call getQueryAndPostProcess directly");
    }

    public queryValues(): Q.Promise<NativeDataset> {
      if (!this.requester) {
        return <Q.Promise<NativeDataset>>Q.reject(new Error('must have a requester to make queries'));
      }
      try {
        var queryAndPostProcess = this.getQueryAndPostProcess();
      } catch (e) {
        return <Q.Promise<NativeDataset>>Q.reject(e);
      }
      if (!hasOwnProperty(queryAndPostProcess, 'query') || typeof queryAndPostProcess.postProcess !== 'function') {
        return <Q.Promise<NativeDataset>>Q.reject(new Error('no error query or postProcess'));
      }
      return this.requester({ query: queryAndPostProcess.query })
        .then(queryAndPostProcess.postProcess);
    }

    // -------------------------

    public needsIntrospect(): boolean {
      return !this.attributes;
    }

    public getIntrospectQueryAndPostProcess(): IntrospectQueryAndPostProcess<any> {
      throw new Error("can not call getIntrospectQueryAndPostProcess directly");
    }

    public introspect(): Q.Promise<RemoteDataset> {
      if (this.attributes) {
        return Q(this);
      }

      if (!this.requester) {
        return <Q.Promise<RemoteDataset>>Q.reject(new Error('must have a requester to introspect'));
      }
      try {
        var queryAndPostProcess = this.getIntrospectQueryAndPostProcess();
      } catch (e) {
        return <Q.Promise<RemoteDataset>>Q.reject(e);
      }
      if (!hasOwnProperty(queryAndPostProcess, 'query') || typeof queryAndPostProcess.postProcess !== 'function') {
        return <Q.Promise<RemoteDataset>>Q.reject(new Error('no error query or postProcess'));
      }
      var value = this.valueOf();
      var ClassFn = Dataset.classMap[this.source];
      return this.requester({ query: queryAndPostProcess.query })
        .then(queryAndPostProcess.postProcess)
        .then((attributes: Lookup<AttributeInfo>) => {
          value.attributes = attributes;
          return <RemoteDataset>(new ClassFn(value));
        })
    }
  }
}
