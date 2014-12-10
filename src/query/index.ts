"use strict";

import Basics = require("../basics") // Prop up
import Lookup = Basics.Lookup;

export import AttributeMetaModule = require("../query/attributeMeta");
export import AttributeMeta = AttributeMetaModule.AttributeMeta;
export import UniqueAttributeMeta = AttributeMetaModule.UniqueAttributeMeta;
export import HistogramAttributeMeta = AttributeMetaModule.HistogramAttributeMeta;
export import RangeAttributeMeta = AttributeMetaModule.RangeAttributeMeta;

export import FacetFilterModule = require("../query/filter")
export import FacetFilter = FacetFilterModule.FacetFilter;
export import FalseFilter = FacetFilterModule.FalseFilter;
export import TrueFilter = FacetFilterModule.TrueFilter;
export import IsFilter = FacetFilterModule.IsFilter;
export import InFilter = FacetFilterModule.InFilter;
export import WithinFilter = FacetFilterModule.WithinFilter;
export import MatchFilter = FacetFilterModule.MatchFilter;
export import ContainsFilter = FacetFilterModule.ContainsFilter;
export import NotFilter = FacetFilterModule.NotFilter;
export import AndFilter = FacetFilterModule.AndFilter;
export import OrFilter = FacetFilterModule.OrFilter;

export import FacetSplitModule = require("../query/split");
export import FacetSplit = FacetSplitModule.FacetSplit;
export import IdentitySplit = FacetSplitModule.IdentitySplit;
export import ContinuousSplit = FacetSplitModule.ContinuousSplit;
export import TimePeriodSplit = FacetSplitModule.TimePeriodSplit;
export import TupleSplit = FacetSplitModule.TupleSplit;
export import ParallelSplit = FacetSplitModule.ParallelSplit;

export import FacetApplyModule = require("../query/apply");
export import FacetApply = FacetApplyModule.FacetApply;
export import ConstantApply = FacetApplyModule.ConstantApply;
export import CountApply = FacetApplyModule.CountApply;
export import SumApply = FacetApplyModule.SumApply;
export import AverageApply = FacetApplyModule.AverageApply;
export import MinApply = FacetApplyModule.MinApply;
export import MaxApply = FacetApplyModule.MaxApply;
export import UniqueCountApply = FacetApplyModule.UniqueCountApply;
export import QuantileApply = FacetApplyModule.QuantileApply;

export import FacetCombineModule = require("../query/combine");
export import FacetCombine = FacetCombineModule.FacetCombine;
export import SliceCombine = FacetCombineModule.SliceCombine;
export import MatrixCombine = FacetCombineModule.MatrixCombine;

export import CondensedCommandModule = require("../query/condensedCommand");
export import CondensedCommand = CondensedCommandModule.CondensedCommand;

export import FacetQueryModule = require("../query/query");
export import FacetQuery = FacetQueryModule.FacetQuery;

export import SegmentTreeModule = require("../query/segmentTree");
export import SegmentTree = SegmentTreeModule.SegmentTree;
export import SegmentTreeValue = SegmentTreeModule.SegmentTreeValue;
export import Prop = SegmentTreeModule.Prop;

export import ApplySimplifierModule = require("../query/applySimplifier");
export import ApplySimplifier = ApplySimplifierModule.ApplySimplifier;
