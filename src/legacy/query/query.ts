module Legacy {
  export interface CommandJS {
    operation: string;
    name?: string;
    type?: string;
    attribute?: string;
    value?: any;
    values?: any[];
    expression?: string;
    range?: any[];
    filter?: any;
    filters?: any[];
    aggregate?: string;
    arithmetic?: string;
    dataset?: string;
    quantile?: number;
    operands?: any[];
    options?: any;
  }

  export class FacetQuery {
    static isFacetQuery(candidate: any): boolean {
      return isInstanceOf(candidate, FacetQuery);
    }

    static fromJS(commands: CommandJS[]): FacetQuery {
      return new FacetQuery(commands);
    }

    public datasets: FacetDataset[];
    public filter: FacetFilter;
    public condensedCommands: CondensedCommand[];

    constructor(commands: CommandJS[]) {
      if (!Array.isArray(commands)) {
        throw new TypeError("query spec must be an array");
      }
      var numCommands = commands.length;
      this.datasets = [];
      var i = 0;
      while (i < numCommands) {
        var command = commands[i];
        if (command.operation !== "dataset") {
          break;
        }
        this.datasets.push(FacetDataset.fromJS(command));
        i++;
      }

      if (this.datasets.length === 0) {
        this.datasets.push(FacetDataset.BASE);
      }
      this.filter = null;
      if (i < numCommands && commands[i].operation === "filter") {
        this.filter = FacetFilter.fromJS(command);
        i++;
      }

      var hasDataset: Lookup<boolean> = {};
      this.datasets.forEach((dataset) => hasDataset[dataset.name] = true);
      this.condensedCommands = [new CondensedCommand()];
      while (i < numCommands) {
        command = commands[i];
        var curGroup = this.condensedCommands[this.condensedCommands.length - 1];

        switch (command.operation) {
          case "dataset":
          case "filter":
            throw new Error(command.operation + " not allowed here");
            break;
          case "split":
            var split = FacetSplit.fromJS(command);
            split.getDatasets().forEach((dataset) => {
              if (!hasDataset[dataset]) {
                throw new Error("split dataset '" + dataset + "' is not defined");
              }
            });

            curGroup = new CondensedCommand();
            curGroup.setSplit(split);
            this.condensedCommands.push(curGroup);
            break;
          case "apply":
            var apply = FacetApply.fromJS(command);
            if (!apply.name) {
              throw new Error("base apply must have a name");
            }
            var datasets = apply.getDatasets();
            datasets.forEach((dataset) => {
              if (!hasDataset[dataset]) {
                throw new Error("apply dataset '" + dataset + "' is not defined");
              }
            });
            curGroup.addApply(apply);
            break;
          case "combine":
            curGroup.setCombine(FacetCombine.fromJS(command));
            break;
          default:
            if (typeof command !== "object") {
              throw new Error("unrecognizable command");
            }
            if (!command.hasOwnProperty("operation")) {
              throw new Error("operation not defined");
            }
            if (typeof command.operation !== "string") {
              throw new Error("invalid operation");
            }
            throw new Error("unknown operation '" + command.operation + "'");
        }

        i++;
      }
    }

    public toString() {
      return "FacetQuery";
    }

    public valueOf() {
      var spec: CommandJS[] = [];

      if (!(this.datasets.length === 1 && this.datasets[0] === FacetDataset.BASE)) {
        this.datasets.forEach((dataset) => {
          var datasetSpec = dataset.toJS();
          datasetSpec.operation = "dataset";
          return spec.push(<CommandJS>datasetSpec);
        });
      }

      if (this.filter) {
        var filterSpec = this.filter.toJS();
        filterSpec.operation = "filter";
        spec.push(<CommandJS>filterSpec);
      }

      this.condensedCommands.forEach((condensedCommand) => condensedCommand.appendToSpec(spec));

      return spec;
    }

    public toJS() {
      return this.valueOf();
    }

    public toJSON() {
      return this.valueOf();
    }

    public getDatasets() {
      return this.datasets;
    }

    public getDatasetFilter(datasetName: string) {
      var datasets = this.datasets;
      for (var i = 0; i < datasets.length; i++) {
        var dataset = datasets[i];
        if (dataset.name === datasetName) {
          return dataset.getFilter();
        }
      }
      return null;
    }

    public getFilter() {
      return this.filter || FacetFilter.TRUE;
    }

    public getFiltersByDataset(extraFilter: FacetFilter = null): FiltersByDataset {
      extraFilter || (extraFilter = FacetFilter.TRUE);
      if (!FacetFilter.isFacetFilter(extraFilter)) {
        throw new TypeError("extra filter should be a FacetFilter");
      }
      var commonFilter = new AndFilter([this.getFilter(), extraFilter]).simplify();
      var filtersByDataset: FiltersByDataset = {};
      this.datasets.forEach((dataset) => filtersByDataset[dataset.name] = new AndFilter([commonFilter, dataset.getFilter()]).simplify());
      return filtersByDataset;
    }

    public getFilterComplexity(): number {
      var complexity = this.getFilter().getComplexity();
      this.datasets.forEach((dataset) => complexity += dataset.getFilter().getComplexity());
      return complexity;
    }

    public getCondensedCommands(): CondensedCommand[] {
      return this.condensedCommands;
    }

    public getSplits(): FacetSplit[] {
      var splits = this.condensedCommands.map((parameters) => parameters.split);
      splits.shift();
      return splits;
    }

    public getApplies() {
      var applies: FacetApply[] = [];
      var condensedCommands = this.condensedCommands;
      for (var i = 0; i < condensedCommands.length; i++) {
        var condensedCommand = condensedCommands[i];
        var commandApplies = condensedCommand.applies;
        for (var j = 0; j < commandApplies.length; j++) {
          var apply = commandApplies[j];
          var alreadyListed = find(applies, (existingApply) => existingApply.name === apply.name && existingApply.equals(apply));
          if (alreadyListed) {
            continue;
          }
          applies.push(apply);
        }
      }
      return applies;
    }

    public getCombines() {
      var combines = this.condensedCommands.map((parameters) => parameters.combine);
      combines.shift();
      return combines;
    }
  }
}
