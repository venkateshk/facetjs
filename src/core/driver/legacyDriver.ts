module Core {
  import LegacyDriver = Legacy.Driver;
  import LegacyQuery = Legacy.FacetQuery;

  export interface Translation {
    query: () => Q.Promise<Dataset>;
    path: string[];
    name: string;
    leftOver?: Expression;
  }

  function makeFacetFilter(expression: Expression): any {
    if (expression.type !== 'BOOLEAN') return null;

    if (expression instanceof LiteralExpression) {
      return {
        type: String(expression.value)
      };
    } else if (expression instanceof IsExpression) {
      if (expression.lhs.isOp('ref') && expression.rhs.isOp('literal')) {
        return {
          type: 'is',
          attribute: (<RefExpression>expression.lhs).name,
          value: (<LiteralExpression>expression.rhs).value
        };
      } else {
        return null;
      }
    } else if (expression instanceof InExpression) {
      if (expression.lhs.isOp('ref') && expression.rhs.isOp('literal') && expression.rhs.type === 'SET') {
        return {
          type: 'in',
          attribute: (<RefExpression>expression.lhs).name,
          values: (<LiteralExpression>expression.rhs).value.toJS().values
        };
      } else {
        return null;
      }
    } else if (expression instanceof NotExpression) {
      var subFilter = makeFacetFilter(expression.operand);
      if (subFilter) {
        return {
          type: 'not',
          filter: subFilter
        };
      } else {
        return null;
      }
    } else if (expression instanceof AndExpression) {
      var subFilters = expression.operands.map(makeFacetFilter);
      if (subFilters.every(Boolean)) {
        return {
          type: 'and',
          filters: subFilters
        }
      } else {
        return null;
      }
    } else if (expression instanceof OrExpression) {
      var subFilters = expression.operands.map(makeFacetFilter);
      if (subFilters.every(Boolean)) {
        return {
          type: 'or',
          filters: subFilters
        };
      } else {
        return null;
      }
    }
    return null;
  }

  function makeFacetApply(expression: Expression): any {
    if (expression.type !== 'NUMBER') return null;

    if (expression instanceof LiteralExpression) {
      return {
        aggregate: 'constant',
        value: expression.value
      };
    } else if (expression instanceof AggregateExpression) {
      if (expression.fn === 'count') {
        return { aggregate: 'count' }
      }

      var attribute = expression.attribute;
      if (attribute instanceof RefExpression) {
        return {
          aggregate: expression.fn,
          attribute: attribute.name
        }
      } else {
        return null;
      }
    }
    return null;
  }

  function makeFacetSplit(expression: Expression, datasetName: string): any {
    if (expression.type !== 'DATASET') return null;

    // facet('dataName').split(ex).label('poo')
    if (expression instanceof LabelExpression) {
      var name = expression.name;
      var splitAgg = expression.operand;
      if (splitAgg instanceof AggregateExpression) {
        var datasetRef = splitAgg.operand;
        if (datasetRef instanceof RefExpression) {
          if (datasetRef.name !== datasetName) return null;
        } else {
          return null;
        }

        var attr = splitAgg.attribute;
        if (attr instanceof RefExpression) {
          return {
            name: name,
            bucket: 'identity',
            attribute: attr.name
          };
        } else if (attr instanceof NumberBucketExpression) {
          return { }; // ToDo: fill this in
        } else if (attr instanceof TimeBucketExpression) {
          return { }; // ToDo: fill this in
        }
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  function getFilter(expression: Expression): any {
    if (expression.type !== 'DATASET') return null;
    if (expression instanceof LiteralExpression) {
      return { type: 'true' };
    } else if (expression instanceof ActionsExpression) {
      var actions = expression.actions;
      if (actions.some((action) => action.action !== 'filter')) return null;
      return makeFacetFilter(actions[0].expression); // ToDo: multiple filters?
    } else {
      return null
    }
  }

  export function legacyTranslator(expression: Expression): LegacyQuery {
    if (expression instanceof ActionsExpression) {
      if (!expression.operand.isOp('literal') || expression.operand.type !== 'DATASET') {
        return null
      }

      var query: any[] = [];
      var datasetName: string;
      var actions = expression.actions;
      var action = actions[0];
      if (action instanceof DefAction) {
        if (action.expression.type !== 'DATASET') throw new Error("can not have non DATASET def actions");
        var filter = getFilter(action.expression);
        if (filter) {
          datasetName = action.name;
          if (filter.type !== 'true') {
            filter.operation = 'filter';
            query.push(filter);
          }
        } else {
          throw new Error('unsupported filter');
        }
      } else {
        throw new Error('must have dataset');
      }

      var seenSplit = false;
      for (var i = 1; i < actions.length; i++) {
        var action = actions[i];
        if (action instanceof ApplyAction) {
          if (action.expression.type === 'NUMBER') {
            var apply = makeFacetApply(action.expression);
            if (apply) {
              apply.operation = 'apply';
              apply.name = action.name;
              query.push(apply);
            } else {
              throw new Error('unsupported apply');
            }
          } else if (action.expression.type === 'DATASET') {
            if (seenSplit) throw new Error("Can have at most one split");
            legacyTranslatorSplit(action.expression, datasetName, query);
          } else {
            throw new Error("can not have non NUMBER or DATASET apply actions");
          }
        }
      }
    } else {
      return null
    }

    return LegacyQuery.fromJS(query);
  }

  function legacyTranslatorSplit(expression: Expression, datasetName: string, query: any[]): void {
    if (expression instanceof ActionsExpression) {
      var split = makeFacetSplit(expression.operand, datasetName);
      if (split) {
        split.operation = 'split';
        query.push(split);
      } else {
        throw new Error('unsupported split');
      }

      var actions = expression.actions;
      var action = actions[0];
      if (action instanceof DefAction) {
        if (action.expression.type !== 'DATASET') throw new Error("must be filtered on the datasource");
        // ToDo: more checks here, maybe some sort of match expression
      } else {
        throw new Error('must have dataset');
      }

      var seenSplit = false;
      for (var i = 1; i < actions.length; i++) {
        var action = actions[i];
        if (action instanceof ApplyAction) {
          if (action.expression.type === 'NUMBER') {
            var apply = makeFacetApply(action.expression);
            if (apply) {
              apply.operation = 'apply';
              apply.name = action.name;
              query.push(apply);
            } else {
              throw new Error('unsupported apply');
            }
          } else if (action.expression.type === 'DATASET') {
            if (seenSplit) throw new Error("Can have at most one split");
            legacyTranslatorSplit(action.expression, datasetName, query);
          } else {
            throw new Error("can not have non NUMBER or DATASET apply actions");
          }
        }
      }
    } else {
      throw new Error('must split on actions');
    }
  }

  export interface Driver {
    (ex: Expression): Q.Promise<Dataset>;
  }

  export function legacyDriver(oldFaceDriver: LegacyDriver.FacetDriver): Driver {
    return function(ex: Expression): Q.Promise<Dataset> {
      var deferred = <Q.Deferred<Dataset>>Q.defer();
      var legacyQuery = legacyTranslator(ex);
      oldFaceDriver({
        query: legacyQuery
      }, (err: Error, segmentTree: Legacy.SegmentTree) => {
        console.log("err", err);
      })
      return deferred.promise;
    }
  }
}
