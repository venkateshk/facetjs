module Legacy {
  export interface AppliesByDataset {
    [dataset: string]: FacetApply[];
  }

  export interface PostProcessorScheme<Inter, Final> {
    constant: (apply: ConstantApply) => Inter;
    getter: (apply: FacetApply) => Inter;
    arithmetic: (arithmetic: string, lhs: Inter, rhs: Inter) => Inter;
    finish: (name: string, getter: Inter) => Final;
  }

  export interface ApplySimplifierParameters<Inter, Final> {
    postProcessorScheme: PostProcessorScheme<Inter, Final>;
    namePrefix?: string;
    topLevelConstant?: string;
    breakToSimple?: boolean;
    breakAverage?: boolean;
  }

  export class ApplySimplifier<Inter, Final> {
    static JS_POST_PROCESSOR_SCHEME: PostProcessorScheme<(p: Prop) => number, (p: Prop) => void> = {
      constant: (parameters) => {
        var value = parameters.value;
        return () => value;
      },
      getter: (parameters) => {
        var name = parameters.name;
        return (prop: Prop) => prop[name];
      },
      arithmetic: (arithmetic, lhs, rhs) => {
        switch (arithmetic) {
          case "add":
            return (prop: Prop) => lhs(prop) + rhs(prop);
          case "subtract":
            return (prop: Prop) => lhs(prop) - rhs(prop);
          case "multiply":
            return (prop: Prop) => lhs(prop) * rhs(prop);
          case "divide":
            return (prop: Prop) => {
              var rv = rhs(prop);
              if (rv === 0) {
                return 0;
              } else {
                return lhs(prop) / rv;
              }
            };
          default:
            throw new Error("Unknown arithmetic '" + arithmetic + "'");
        }
      },
      finish: (name, getter) => (prop: Prop) => prop[name] = getter(prop)
    };

    private postProcessorScheme: PostProcessorScheme<Inter, Final>;
    private namePrefix: string;
    private topLevelConstant: string;
    private breakToSimple: boolean;
    private breakAverage: boolean;
    private separateApplyGetters: any[] = [];
    private postProcess: any[] = [];
    private nameIndex: number = 0;

    constructor(parameters: ApplySimplifierParameters<Inter, Final>) {
      this.postProcessorScheme = parameters.postProcessorScheme;
      if (!this.postProcessorScheme) throw new TypeError("Must have a postProcessorScheme");
      this.namePrefix = parameters.namePrefix || "_S";
      this.topLevelConstant = parameters.topLevelConstant || "process";
      this.breakToSimple = Boolean(parameters.breakToSimple);
      this.breakAverage = Boolean(parameters.breakAverage);
    }

    public _getNextName(sourceApplyName: string) {
      this.nameIndex++;
      return this.namePrefix + this.nameIndex + "_" + sourceApplyName;
    }

    public _addBasicApply(apply: FacetApply, sourceApplyName: string): Inter {
      if (apply.aggregate === "constant") {
        return this.postProcessorScheme.constant(<ConstantApply>apply);
      }

      if (apply.aggregate === "average" && this.breakAverage) {
        return this._addArithmeticApply((<AverageApply>apply).decomposeAverage(), sourceApplyName);
      }

      if (apply.name) {
        var myApplyGetter = {
          apply: apply,
          getter: this.postProcessorScheme.getter(apply),
          sourceApplyNames: {}
        };
        this.separateApplyGetters.push(myApplyGetter);
      } else {
        apply = apply.addName(this._getNextName(sourceApplyName));
        myApplyGetter = find(this.separateApplyGetters, (ag) => ag.apply.equals(apply));
        if (!myApplyGetter) {
          myApplyGetter = {
            apply: apply,
            getter: this.postProcessorScheme.getter(apply),
            sourceApplyNames: {}
          };
          this.separateApplyGetters.push(myApplyGetter);
        }
      }

      (<any>myApplyGetter.sourceApplyNames)[sourceApplyName] = 1;
      return myApplyGetter.getter;
    }

    public _addArithmeticApply(apply: FacetApply, sourceApplyName: string): Inter {
      var operands = apply.operands;
      var op1 = operands[0];
      var op2 = operands[1];
      var lhs = op1.arithmetic ? this._addArithmeticApply(op1, sourceApplyName) : this._addBasicApply(op1, sourceApplyName);
      var rhs = op2.arithmetic ? this._addArithmeticApply(op2, sourceApplyName) : this._addBasicApply(op2, sourceApplyName);
      return this.postProcessorScheme.arithmetic(apply.arithmetic, lhs, rhs);
    }

    public _addSingleDatasetApply(apply: FacetApply, sourceApplyName: string): any {
      if (apply.aggregate === "constant") {
        return this.postProcessorScheme.constant(<ConstantApply>apply);
      }

      if (this.breakToSimple) {
        if (apply.aggregate === "average" && this.breakAverage) {
          apply = (<AverageApply>apply).decomposeAverage();
        }

        if (apply.arithmetic) {
          return this._addArithmeticApply(apply, sourceApplyName);
        } else {
          return this._addBasicApply(apply, sourceApplyName);
        }
      } else {
        return this._addBasicApply(apply, sourceApplyName);
      }
    }

    public _addMultiDatasetApply(apply: FacetApply, sourceApplyName: string): any {
      var operands = apply.operands;
      var op1 = operands[0];
      var op2 = operands[1];
      var op1Datasets = op1.getDatasets();
      var op2Datasets = op2.getDatasets();
      var lhs = op1Datasets.length <= 1 ? this._addSingleDatasetApply(op1, sourceApplyName) : this._addMultiDatasetApply(op1, sourceApplyName);
      var rhs = op2Datasets.length <= 1 ? this._addSingleDatasetApply(op2, sourceApplyName) : this._addMultiDatasetApply(op2, sourceApplyName);
      return this.postProcessorScheme.arithmetic(apply.arithmetic, lhs, rhs);
    }

    public addApplies(applies: FacetApply[]) {
      var multiDatasetApplies: FacetApply[] = [];
      applies.forEach((apply) => {
        var applyName = apply.name;
        var getter: Inter;
        switch (apply.getDatasets().length) {
          case 0:
            getter = this.postProcessorScheme.constant(<ConstantApply>apply);
            switch (this.topLevelConstant) {
              case "process":
                return this.postProcess.push(this.postProcessorScheme.finish(applyName, getter));
              case "leave":
                return this.separateApplyGetters.push({
                  apply: apply,
                  getter: getter,
                  sourceApplyName: applyName
                });
              case "ignore":
                return null;
              default:
                throw new Error("unknown topLevelConstant");
            }
            break;
          case 1:
            getter = this._addSingleDatasetApply(apply, applyName);
            if (this.breakToSimple && (apply.arithmetic || (apply.aggregate === "average" && this.breakAverage))) {
              return this.postProcess.push(this.postProcessorScheme.finish(applyName, getter));
            }
            break;
          default:
            multiDatasetApplies.push(apply);
        }
      });

      multiDatasetApplies.forEach((apply) => {
        var applyName = apply.name;
        var getter = this._addMultiDatasetApply(apply, applyName);
        return this.postProcess.push(this.postProcessorScheme.finish(applyName, getter));
      });

      return this;
    }

    public getSimpleApplies() {
      return this.separateApplyGetters.map((parameters) => parameters.apply);
    }

    public getSimpleAppliesByDataset(): AppliesByDataset {
      var appliesByDataset: AppliesByDataset = {};
      var separateApplyGetters = this.separateApplyGetters;
      for (var i = 0; i < separateApplyGetters.length; i++) {
        var apply = separateApplyGetters[i].apply;
        var dataset = apply.getDataset();
        appliesByDataset[dataset] || (appliesByDataset[dataset] = []);
        appliesByDataset[dataset].push(apply);
      }
      return appliesByDataset;
    }

    public getPostProcessors() {
      return this.postProcess;
    }

    public getApplyComponents(applyName: string) {
      return this.separateApplyGetters.filter((parameters) => {
        var sourceApplyNames = parameters.sourceApplyNames;
        return sourceApplyNames[applyName];
      }).map((parameters) => {
        return parameters.apply;
      });
    }
  }
}
