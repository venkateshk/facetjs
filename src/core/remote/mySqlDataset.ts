module Core {
  interface SQLDescribeRow {
    Field: string;
    Type: string;
  }

  function correctResult(result: any[]): boolean {
    return Array.isArray(result) && (result.length === 0 || typeof result[0] === 'object');
  }

  function postProcess(res: any[]): NativeDataset {
    if (!correctResult(res)) {
      var err = new Error("unexpected result from MySQL");
      (<any>err).result = res; // ToDo: special error type
      throw err;
    }
    return new NativeDataset({ source: 'native', data: res });
  }

  function postProcessIntrospect(columns: SQLDescribeRow[]): Lookup<AttributeInfo> {
    var attributes: Lookup<AttributeInfo> = Object.create(null);
    columns.forEach((column: SQLDescribeRow) => {
      var sqlType = column.Type;
      if (sqlType === "datetime") {
        attributes[column.Field] = new AttributeInfo({ type: 'TIME' });
      } else if (sqlType.indexOf("varchar(") === 0) {
        attributes[column.Field] = new AttributeInfo({ type: 'STRING' });
      } else if (sqlType.indexOf("int(") === 0 || sqlType.indexOf("bigint(") === 0) {
        // ToDo: make something special for integers
        attributes[column.Field] = new AttributeInfo({ type: 'NUMBER' });
      } else if (sqlType.indexOf("decimal(") === 0) {
        attributes[column.Field] = new AttributeInfo({ type: 'NUMBER' });
      }
    });
    return attributes;
  }

  export class MySQLDataset extends RemoteDataset {
    static type = 'DATASET';

    static fromJS(datasetJS: any): MySQLDataset {
      var value = RemoteDataset.jsToValue(datasetJS);
      value.table = datasetJS.table;
      return new MySQLDataset(value);
    }

    public table: string;

    constructor(parameters: DatasetValue) {
      super(parameters, dummyObject);
      this._ensureSource("mysql");
      this.table = parameters.table;
    }

    public valueOf(): DatasetValue {
      var value = super.valueOf();
      value.table = this.table;
      return value;
    }

    public toJS(): DatasetJS {
      var js = super.toJS();
      js.table = this.table;
      return js;
    }

    public equals(other: MySQLDataset): boolean {
      return super.equals(other) &&
        this.table === other.table;
    }

    public toHash(): string {
      return super.toHash() + ':' + this.table;
    }

    // -----------------

    public canHandleFilter(ex: Expression): boolean {
      return true;
    }

    public canHandleTotal(): boolean {
      return true;
    }

    public canHandleSplit(ex: Expression): boolean {
      return true;
    }

    public canHandleSort(sortAction: SortAction): boolean {
      return true;
    }

    public canHandleLimit(limitAction: LimitAction): boolean {
      return true;
    }

    public canHandleHavingFilter(ex: Expression): boolean {
      return true;
    }

    // -----------------

    public getQueryAndPostProcess(): QueryAndPostProcess<string> {
      var table = "`" + this.table + "`";
      switch (this.mode) {
        case 'raw':
          var query = [
            'SELECT',
            '`' + Object.keys(this.attributes).join('`, `') + '`'
          ];
          query.push('FROM', table);
          if (!(this.filter.equals(Expression.TRUE))) {
            query.push('WHERE', this.filter.getSQL());
          }
          return {
            query: query.join(' '),
            postProcess: postProcess
          };

        case 'total':
          var query = [
            'SELECT',
            this.applies.map((apply) => apply.getSQL()).join(', ')
          ];
          query.push('FROM', table);
          if (!(this.filter.equals(Expression.TRUE))) {
            query.push('WHERE', this.filter.getSQL());
          }
          query.push('GROUP BY 1');
          return {
            query: query.join(' '),
            postProcess: postProcess
          };

        case 'split':
          var splitSQL = this.split.getSQL();
          var query = [
            'SELECT',
            `${splitSQL} AS '${this.label}',`,
            this.applies.map((apply) => apply.getSQL()).join(', ')
          ];
          query.push('FROM', table);
          if (!(this.filter.equals(Expression.TRUE))) {
            query.push('WHERE', this.filter.getSQL());
          }
          query.push('GROUP BY', splitSQL);
          if (!(this.havingFilter.equals(Expression.TRUE))) {
            query.push('HAVING', this.havingFilter.getSQL());
          }
          if (this.sort) {
            query.push(this.sort.getSQL());
          }
          if (this.limit) {
            query.push(this.limit.getSQL());
          }
          return {
            query: query.join(' '),
            postProcess: postProcess
          };

        default:
          throw new Error("can not get query for: " + this.mode);
      }
    }

    public getIntrospectQueryAndPostProcess(): IntrospectQueryAndPostProcess<string> {
      return {
        query: "DESCRIBE `" + this.table + "`",
        postProcess: postProcessIntrospect
      };
    }
  }
  Dataset.register(MySQLDataset, 'mysql');
}
