/// <reference path="../../typings/tsd.d.ts" />
"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

import HigherObjectModule = require("higher-object");
import isInstanceOf = HigherObjectModule.isInstanceOf;

import SplitModule = require("./split");
import FacetSplit = SplitModule.FacetSplit;
import ParallelSplit = SplitModule.ParallelSplit;

import FacetApplyModule = require("./apply");
import FacetApply = FacetApplyModule.FacetApply;

import FacetCombineModule = require("./combine");
import FacetCombine = FacetCombineModule.FacetCombine;
import SliceCombine = FacetCombineModule.SliceCombine;

import SegmentTreeModule = require("./segmentTree");
import Prop = SegmentTreeModule.Prop;

export class CondensedCommand {
  public knownProps: any = {};
  public split: FacetSplit;
  public applies: FacetApply[];
  public combine: FacetCombine;

  constructor() {
    this.split = null;
    this.applies = [];
    this.combine = null;
  }

  public setSplit(split: FacetSplit) {
    if (this.split) {
      throw new Error("split already defined");
    }
    this.split = split;
    if (split.name) {
      this.knownProps[split.name] = split;
    }
  }

  public addApply(apply: FacetApply) {
    this.applies.push(apply);
    return this.knownProps[apply.name] = apply;
  }

  public setCombine(combine: FacetCombine) {
    if (!this.split) {
      throw new Error("combine called without split");
    }
    if (this.combine) {
      throw new Error("can not combine more than once");
    }
    if (combine.sort && !this.knownProps[combine.sort.prop]) {
      throw new Error("sort on unknown prop '" + combine.sort.prop + "'");
    }
    this.combine = combine;
  }

  public getDatasets(): string[] {
    if (this.split) {
      return this.split.getDatasets();
    }
    var datasets: string[] = [];
    var applies = this.applies;
    for (var i = 0; i < applies.length; i++) {
      var apply = applies[i];
      var applyDatasets = apply.getDatasets();
      for (var j = 0; j < applyDatasets.length; j++) {
        var dataset = applyDatasets[j];
        if (datasets.indexOf(dataset) >= 0) continue;
        datasets.push(dataset);
      }
    }
    return datasets;
  }

  public getSplit() {
    return this.split;
  }

  public getEffectiveSplit(): FacetSplit {
    if (!this.split || this.split.bucket !== "parallel") {
      return this.split;
    }
    var split = <ParallelSplit>this.split;

    // ToDo: wtf does this do?
    var sortBy = this.getSortBy();
    if (isInstanceOf(sortBy, FacetSplit)) {
      return this.split;
    }

    var sortDatasets = sortBy.getDatasets();
    var effectiveSplits = split.splits.filter((split) => {
      return sortDatasets.indexOf(split.getDataset()) >= 0;
    });

    switch (effectiveSplits.length) {
      case 0:
        return split.splits[0];
      case 1:
        return effectiveSplits[0].addName(split.name);
      default:
        return new ParallelSplit({
          name: split.name,
          splits: effectiveSplits,
          segmentFilter: split.segmentFilter
        });
    }
  }

  public getApplies(): FacetApply[] {
    return this.applies;
  }

  public getCombine() {
    if (this.combine) {
      return this.combine;
    }
    if (this.split) {
      return SliceCombine.fromJS({
        sort: {
          compare: "natural",
          prop: this.split.name,
          direction: "ascending"
        }
      });
    } else {
      return null;
    }
  }

  public getSortBy() {
    return this.knownProps[this.getCombine().sort.prop];
  }

  public getSortHash(): string {
    var combine = this.getCombine();
    var sort = combine.sort;
    return (this.knownProps[sort.prop].toHash()) + "#" + sort.direction;
  }

  public getZeroProp(): Prop {
    var zeroProp: Prop = {};
    this.applies.forEach((apply) => zeroProp[apply.name] = <any>0); // ToDo: remove <any> after union
    return zeroProp;
  }

  public appendToSpec(spec: any[]): void {
    if (this.split) {
      var splitJS = this.split.toJS();
      splitJS.operation = "split";
      spec.push(splitJS);
    }

    this.applies.forEach((apply) => {
      var applyJS = apply.toJS();
      applyJS.operation = "apply";
      return spec.push(applyJS);
    });

    if (this.combine) {
      var combineJS = this.combine.toJS();
      combineJS.operation = "combine";
      spec.push(combineJS);
    }

  }
}

