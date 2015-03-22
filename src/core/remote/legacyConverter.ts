module Core {
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
      if (expression.lhs.isOp('ref') && expression.rhs.isOp('literal')) {
        if (expression.rhs.type === 'SET') {
          return {
            type: 'in',
            attribute: (<RefExpression>expression.lhs).name,
            values: (<LiteralExpression>expression.rhs).value.toJS().values
          };
        } else if (expression.rhs.type === 'TIME_RANGE' || expression.rhs.type === 'NUMBER_RANGE') {
          var timeRange = <TimeRange>(<LiteralExpression>expression.rhs).value;
          return {
            type: 'within',
            attribute: (<RefExpression>expression.lhs).name,
            range: [timeRange.start, timeRange.end]
          };
        } else {
          return null;
        }
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
          var subAttr = attr.operand;
          if (subAttr instanceof RefExpression) {
            return {
              name: name,
              bucket: 'continuous',
              attribute: subAttr.name,
              size: attr.size,
              offset: attr.offset
            };
          } else {
            return null;
          }
        } else if (attr instanceof TimeBucketExpression) {
          var subAttr = attr.operand;
          if (subAttr instanceof RefExpression) {
            return {
              name: name,
              bucket: 'timePeriod',
              attribute: subAttr.name,
              period: attr.duration,
              timezone: attr.timezone
            };
          } else {
            return null;
          }
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

  export function legacyTranslator(expression: Expression): Legacy.FacetQuery {
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

      var splitPart: any[] = null;
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
            if (splitPart) throw new Error("Can have at most one split");
            splitPart = legacyTranslatorSplit(action.expression, datasetName);
          } else {
            throw new Error("can not have non NUMBER or DATASET apply actions");
          }
        }
      }
    } else {
      return null
    }

    return Legacy.FacetQuery.fromJS(query.concat(splitPart || []));
  }

  function legacyTranslatorSplit(expression: Expression, datasetName: string): any[] {
    var query: any[] = [];
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

      var combine: any = {
        operation: 'combine'
      };
      var splitPart: any[] = null;
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
            if (splitPart) throw new Error("Can have at most one split");
            splitPart = legacyTranslatorSplit(action.expression, datasetName);
          } else {
            throw new Error("can not have non NUMBER or DATASET apply actions");
          }
        } else if (action instanceof SortAction) {
          var sortExpression = action.expression;
          if (sortExpression instanceof RefExpression) {
            combine.method = 'slice';
            combine.sort = {
              compare: 'natural',
              prop: sortExpression.name,
              direction: action.direction
            };
          }
        } else if (action instanceof LimitAction) {
          combine.limit = action.limit;
        }
      }

      return query.concat([combine], splitPart || []);
    } else {
      throw new Error('must split on actions');
    }
  }

  // --------------

  function segmentTreesToDataset(segmentTrees: Legacy.SegmentTree[], splitNames: string[]): NativeDataset {
    var splitName = splitNames[0];
    var splitNamesTail = splitNames.slice(1);
    return new NativeDataset({
      source: 'native',
      data: segmentTrees.map((segmentTree) => {
        var prop = segmentTree.prop;
        var datum: Datum = {};
        for (var k in prop) {
          var v = prop[k];
          if (!Array.isArray(v)) {
            datum[k] = v;
          } else if (typeof v[0] === 'number') {
            datum[k] = NumberRange.fromJS({ start: v[0], end: v[1] })
          } else {
            datum[k] = TimeRange.fromJS({ start: v[0], end: v[1] })
          }
        }
        if (segmentTree.splits) {
          datum[splitName] = segmentTreesToDataset(segmentTree.splits, splitNamesTail);
        }
        return datum;
      })
    })
  }

  export function legacyConverter(legacyDriver: Legacy.Driver.FacetDriver) {
    return function(ex: Expression): Q.Promise<Dataset> {
      var legacyQuery = legacyTranslator(ex);
      return legacyDriver({
        query: legacyQuery
      }).then((segmentTree) => {
        var splitNames = legacyQuery.getSplits().map((split) => split.name);
        return segmentTreesToDataset([segmentTree], splitNames);
      })
    }
  }
}
