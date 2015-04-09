module Facet.Legacy {
  interface LRUCacheParameters {
    name?: string;
    keepFor?: number;
    currentTime?: () => number;
  }

  class LRUCache<T> {
    public name: string;
    public keepFor: number;
    public currentTime: () => number;
    public store: Lookup<{time: number; value: T}>;
    public size: number;

    constructor(parameters: LRUCacheParameters) {
      this.name = parameters.name || "nameless";
      this.keepFor = parameters.keepFor || (30 * 60 * 1000);
      this.currentTime = parameters.currentTime || (() => Date.now());
      if (typeof this.keepFor !== "number") {
        throw new TypeError("keepFor must be a number");
      }
      if (this.keepFor < 5 * 60 * 1000) {
        throw new Error("must keep for at least 5 minutes");
      }
      this.clear();
    }

    public clear() {
      this.store = {};
      this.size = 0;
    }

    public tidy() {
      var trimBefore = this.currentTime() - this.keepFor;
      var store = this.store;
      for (var hash in store) {
        var slot = store[hash];
        if (trimBefore <= slot.time) continue;
        delete store[hash];
        this.size--;
      }
    }

    public get(hash: string): T {
      if (hasOwnProperty(this.store, hash)) {
        var storeSlot = this.store[hash];
        storeSlot.time = this.currentTime();
        return storeSlot.value;
      } else {
        return null;
      }
    }

    public set(hash: string, value: T): void {
      if (!hasOwnProperty(this.store, hash)) {
        this.size++;
      }
      this.store[hash] = {
        value: value,
        time: this.currentTime()
      };
    }

    public getOrCreate(hash: string, createFn: () => T) {
      var ret = this.get(hash);
      if (!ret) {
        ret = createFn();
        this.set(hash, ret);
      }
      return ret;
    }

    public toString() {
      return "[" + this.name + " cache, size: " + this.size + "]";
    }

    public debug() {
      console.log(this.name + " cache");
      console.log("Size: " + this.size);
      var store = this.store;
      for (var hash in store) {
        var slot = store[hash];
        console.log(hash, JSON.stringify(slot));
      }
    }
  }

  interface PostProcessor {
    (p: Prop): void;
  }

  var applySimplifierSettings: ApplySimplifierParameters<(p: Prop) => number, PostProcessor> = {
    namePrefix: "c_S",
    breakToSimple: true,
    topLevelConstant: "process",
    postProcessorScheme: ApplySimplifier.JS_POST_PROCESSOR_SCHEME
  };

  function filterToHash(filter: FacetFilter) {
    return filter.simplify().toHash();
  }

  function filterSplitToHash(datasetMap: Lookup<FacetDataset>, filter: FacetFilter, split: FacetSplit): string {
    var splits = split.bucket === "parallel" ? (<ParallelSplit>split).splits : [split];
    return splits.map((split: FacetSplit) => {
      var dataset = datasetMap[split.getDataset()];
      var andFilter = new AndFilter([dataset.getFilter(), filter]);
      var extract = andFilter.extractFilterByAttribute(split.attribute);
      if (extract) {
        return dataset.source + "#" + (filterToHash(extract[0])) + "//" + (split.toHash());
      } else {
        return dataset.source + "#BAD//" + (split.toHash());
      }
    }).sort().join("*");
  }

  interface ApplyCacheSlot {
    [applyHash: string]: number;
  }

  interface ApplyHash {
    name: string;
    apply: FacetApply;
    applyHash: string;
    segmentHash: string;
  }

  function applyToHash(apply: FacetApply, filter: FacetFilter, datasetMap: Lookup<FacetDataset>): ApplyHash {
    var dataset = datasetMap[apply.getDataset()];
    if (!dataset) {
      throw new Error("Something went wrong: could not find apply dataset");
    }
    var datasetFilter = dataset.getFilter();
    return {
      name: apply.name,
      apply: apply,
      applyHash: apply.toHash(),
      segmentHash: dataset.source + "#" + filterToHash(new AndFilter([filter, datasetFilter]))
    };
  }

  function appliesToHashes(simpleApplies: FacetApply[], filter: FacetFilter, datasetMap: Lookup<FacetDataset>) {
    return simpleApplies.map((apply) => applyToHash(apply, filter, datasetMap));
  }

  function makeDatasetMap(query: FacetQuery) {
    var datasets = query.getDatasets();
    var map: Lookup<FacetDataset> = {};
    datasets.forEach((dataset) => map[dataset.name] = dataset);
    return map;
  }

  interface SortSlot {
    filter: FacetFilter;
    splitValues: any[];
    limit?: number;
    complete?: boolean;
  }

  function betterThanExistingSlot(sortSlot: SortSlot, givenFilter: FacetFilter, givenCombine: SliceCombine, givenSplitValues: any[]) {
    if (!sortSlot) {
      return true;
    }
    var givenComplete = givenCombine.limit != null ? givenSplitValues.length < givenCombine.limit : true;
    if (!sortSlot.splitValues) {
      return true;
    }
    if (!FacetFilter.filterSubset(sortSlot.filter, givenFilter)) {
      return false;
    }
    return !sortSlot.complete || givenComplete;
  }

  function canServeFromSlot(sortSlot: SortSlot, givenFilter: FacetFilter, givenCombine: SliceCombine) {
    if (!(sortSlot && FacetFilter.filterSubset(givenFilter, sortSlot.filter))) {
      return false;
    }

    if (sortSlot.complete) {
      return true;
    }

    if (!givenCombine.limit) {
      return false;
    }

    return givenCombine.limit <= sortSlot.limit;
  }

  function getFilteredValuesFromSlot(sortSlot: SortSlot, split: FacetSplit, myFilter: FacetFilter) {
    if (myFilter.type === "true") {
      return sortSlot.splitValues.slice();
    }
    var splitAttribute = split.attribute;
    var filterFn = myFilter.getFilterFn();
    return sortSlot.splitValues.filter((splitValue) => {
      var row: any = {};
      row[splitAttribute] = splitValue;
      return filterFn(row);
    });
  }

  function isCompleteInput(givenFilter: FacetFilter, givenCombine: SliceCombine, givenSplitValues: any[]) {
    if (givenFilter.type !== "true") {
      return false;
    }
    if (givenCombine.limit != null) {
      return givenSplitValues.length < givenCombine.limit;
    } else {
      return true;
    }
  }

  function getRealSplit(split: FacetSplit): FacetSplit {
    if (split.bucket === "parallel") {
      return (<ParallelSplit>split).splits[0];
    } else {
      return split;
    }
  }

  export interface Flags {
    fullQuery?: boolean;
  }

  export interface CombineToSplits {
    set(filter: FacetFilter, condensedCommand: CondensedCommand, splitValues: any[]): void;
    get(filter: FacetFilter, condensedCommand: CondensedCommand, flags: Flags): any[]
  }

  export class IdentityCombineToSplitValues implements CombineToSplits {
    private bySort: Lookup<SortSlot>;

    constructor() {
      this.bySort = {};
    }

    public set(filter: FacetFilter, condensedCommand: CondensedCommand, splitValues: any[]) {
      var split = getRealSplit(condensedCommand.split);
      var combine = <SliceCombine>(condensedCommand.combine);
      var filterExtract = filter.extractFilterByAttribute(split.attribute);
      if (!filterExtract) return;
      var myFilter = filterExtract[1];

      var sortHash = condensedCommand.getSortHash();
      var sortSlot = this.bySort[sortHash];

      if (betterThanExistingSlot(sortSlot, myFilter, combine, splitValues)) {
        sortSlot = {
          filter: myFilter,
          splitValues: splitValues
        };

        if (isCompleteInput(myFilter, combine, splitValues)) {
          sortSlot.complete = true;
        } else {
          sortSlot.limit = combine.limit;
        }

        this.bySort[sortHash] = sortSlot;
      }

    }

    private _findComplete() {
      var mySort = this.bySort;
      for (var k in mySort) {
        var slot = mySort[k];
        if (slot.complete) return slot;
      }
      return null;
    }

    public get(filter: FacetFilter, condensedCommand: CondensedCommand, flags: Flags) {
      var split = getRealSplit(condensedCommand.split);
      var combine = <SliceCombine>(condensedCommand.combine);
      var filterExtract = filter.extractFilterByAttribute(split.attribute);
      if (!filterExtract) {
        flags.fullQuery = true;
        return null;
      }

      var myFilter = filterExtract[1];

      var sortHash = condensedCommand.getSortHash();
      var sortSlot = this.bySort[sortHash];
      if (canServeFromSlot(sortSlot, filter, combine)) {
        var filteredSplitValues = getFilteredValuesFromSlot(sortSlot, split, myFilter);

        if (sortSlot.complete || combine.limit <= filteredSplitValues.length) {
          driverUtil.inPlaceTrim(filteredSplitValues, combine.limit);
          return filteredSplitValues;
        } else {
          flags.fullQuery = true;
          return filteredSplitValues;
        }
      } else {
        var completeSlot = this._findComplete();
        if (!completeSlot) {
          return null;
        }
        return getFilteredValuesFromSlot(completeSlot, split, myFilter);
      }
    }
  }

  export class TimePeriodCombineToSplitValues implements CombineToSplits {
    private bySort: Lookup<SortSlot>;
    private knownUnknowns: Lookup<number>;

    constructor() {
      this.bySort = {};
    }

    private _getAllPossibleSplitValues(myFilter: FacetFilter, split: TimePeriodSplit): any[] {
      var range = (<WithinFilter>myFilter).range;
      var start = range[0];
      var end = range[1];
      var duration = split.period;
      var timezone = split.timezone;
      var iter = duration.floor(start, timezone);
      var splitValues: any[] = [];
      var next = duration.move(iter, timezone, 1);
      while (next <= end) {
        splitValues.push([iter, next]);
        iter = next;
        next = duration.move(iter, timezone, 1);
      }
      return splitValues;
    }

    private _calculateKnownUnknowns(possibleSplitValues: any[], splitValues: any[]) {
      var hasSplitValue: Lookup<number> = {};
      for (var i = 0; i < splitValues.length; i++) {
        var splitValue = splitValues[i];
        if (!splitValue) continue;
        hasSplitValue[splitValue[0].toISOString()] = 1;
      }
      var knownUnknowns: Lookup<number> = {};
      possibleSplitValues.forEach((possibleSplitValue) => {
        var possibleSplitValueKey = possibleSplitValue[0].toISOString();
        if (!hasSplitValue[possibleSplitValueKey]) {
          return knownUnknowns[possibleSplitValueKey] = 1;
        }
      });

      this.knownUnknowns = knownUnknowns;
    }

    private _getPossibleKnownSplitValues(myFilter: FacetFilter, split: TimePeriodSplit) {
      var splitValues = this._getAllPossibleSplitValues(myFilter, split);

      if (this.knownUnknowns) {
        var knownUnknowns = this.knownUnknowns;
        driverUtil.inPlaceFilter(splitValues, (splitValue) => !knownUnknowns[splitValue[0].toISOString()]);
      }

      return splitValues;
    }

    private _makeRange(split: TimePeriodSplit, splitValues: any[]) {
      var duration = split.period;
      var timezone = split.timezone;
      return splitValues.map((splitValue) => [splitValue, duration.move(splitValue, timezone, 1)]);
    }

    public set(filter: FacetFilter, condensedCommand: CondensedCommand, splitValues: any[]) {
      var split = <TimePeriodSplit>getRealSplit(condensedCommand.split);
      var combine = <SliceCombine>(condensedCommand.combine);
      var filterExtract = filter.extractFilterByAttribute(split.attribute);
      if (!filterExtract) return;

      var myFilter = filterExtract[1];
      if (myFilter.type !== "within") return;

      var sort = combine.sort;
      if (sort.prop === split.name) {
        if (combine.limit != null) {
          return;
        }
        var possibleSplitValues = this._getAllPossibleSplitValues(myFilter, split);
        if (splitValues.length >= possibleSplitValues.length) return;
        this._calculateKnownUnknowns(possibleSplitValues, splitValues);
      } else {
        var sortHash = condensedCommand.getSortHash();
        var sortSlot = this.bySort[sortHash];

        if (betterThanExistingSlot(sortSlot, myFilter, combine, splitValues)) {
          sortSlot = {
            filter: myFilter,
            splitValues: splitValues.map((parameters) => {
              var start = parameters[0];
              return start;
            })
          };

          if (isCompleteInput(myFilter, combine, splitValues)) {
            sortSlot.complete = true;
          } else {
            sortSlot.limit = combine.limit;
          }

          this.bySort[sortHash] = sortSlot;
        }
      }

    }

    public get(filter: FacetFilter, condensedCommand: CondensedCommand, flags: Flags) {
      var split = <TimePeriodSplit>getRealSplit(condensedCommand.split);
      var combine = <SliceCombine>(condensedCommand.combine);

      var filterExtract = filter.extractFilterByAttribute(split.attribute);
      if (!filterExtract) {
        flags.fullQuery = true;
        return null;
      }

      var myFilter = filterExtract[1];
      if (myFilter.type !== "within") {
        flags.fullQuery = true;
        return null;
      }

      var sort = combine.sort;
      if (sort.prop === split.name) {
        var splitValues = this._getPossibleKnownSplitValues(myFilter, split);
        if (sort.direction === "descending") {
          splitValues.reverse();
        }
        if (combine.limit != null) {
          driverUtil.inPlaceTrim(splitValues, combine.limit);
        }
        return splitValues;
      } else {
        var sortHash = condensedCommand.getSortHash();
        var sortSlot = this.bySort[sortHash];
        if (canServeFromSlot(sortSlot, filter, combine)) {
          var filteredSplitValues = getFilteredValuesFromSlot(sortSlot, split, myFilter);

          if ((combine.limit != null) && combine.limit <= filteredSplitValues.length) {
            driverUtil.inPlaceTrim(filteredSplitValues, combine.limit);
          } else {
            flags.fullQuery = true;
          }

          return this._makeRange(split, filteredSplitValues);
        } else {
          return this._getPossibleKnownSplitValues(myFilter, split);
        }
      }
    }
  }

  export class ContinuousCombineToSplitValues implements CombineToSplits {
    constructor() {
    }

    public get(filter: FacetFilter, condensedCommand: CondensedCommand, flags: Flags): any[] {
      throw new Error("not implemented yet");
    }

    public set(filter: FacetFilter, condensedCommand: CondensedCommand, splitValues: any[]): void {
      throw new Error("not implemented yet");
    }
  }

  function sortedApplyValues(hashToApply: Lookup<FacetApply>): FacetApply[] {
    if (hashToApply) {
      return Object.keys(hashToApply).sort().map((h) => hashToApply[h]);
    } else {
      return [];
    }
  }

  function addSortByIfNeeded(applies: FacetApply[], sortBy: any) {
    if (FacetApply.isFacetApply(sortBy) && !driverUtil.find(applies, (apply) => apply.name === sortBy.name)) {
      applies.push(sortBy);
    }
  }

  function nextLayer(segments: SegmentTree[]): SegmentTree[] {
    return driverUtil.flatten(driverUtil.filterMap(segments, (segment) => segment.splits));
  }

  function nextLoadingLayer(segments: SegmentTree[]): SegmentTree[] {
    return nextLayer(segments).filter((segment) => segment.hasLoading());
  }

  function gatherMissingApplies(segments: SegmentTree[]) {
    var totalMissingApplies: Lookup<FacetApply> = null;
    for (var i = 0; i < segments.length; i++) {
      var segment = segments[i];
      var segmentMissingApplies = segment.meta['missingApplies'];
      if (!segmentMissingApplies) continue;
      totalMissingApplies || (totalMissingApplies = {});
      for (var k in segmentMissingApplies) {
        totalMissingApplies[k] = segmentMissingApplies[k];
      }
    }
    return totalMissingApplies;
  }

  function jsWithOpperation(part: any, operation: string): any {
    var js: any = part.toJS();
    js.operation = operation;
    return js;
  }

  export function computeDeltaQuery(originalQuery: FacetQuery, rootSegment: SegmentTree) {
    var datasets = originalQuery.getDatasets();
    var andFilters = [originalQuery.getFilter()];
    var condensedCommands = originalQuery.getCondensedCommands();
    var newQuery: any[] = datasets.length === 1 && datasets[0].name === "main" ? [] : datasets.map((dataset) => {
      return jsWithOpperation(dataset, 'dataset');
    });

    var i = 0;
    var dummySegmentTree = new SegmentTree({prop: {}, splits: [rootSegment]});
    var prevLayer = [dummySegmentTree];

    var currentLayer = nextLoadingLayer(prevLayer);
    var split: FacetSplit;
    while ((!prevLayer[0].loading) && currentLayer.length === 1) {
      split = condensedCommands[i].split;
      if (split) {
        andFilters.push(split.getFilterFor(currentLayer[0].prop));
      }

      prevLayer = currentLayer;
      currentLayer = nextLoadingLayer(prevLayer);
      i++;
    }
    if (!prevLayer[0].meta['missingApplies'] && currentLayer.length && (split = condensedCommands[i].split)) {
      var currentFilter = new OrFilter(currentLayer.map((segment) => split.getFilterFor(segment.prop))).simplify();
      if (currentFilter.type !== "or") {
        andFilters.push(currentFilter);
      }
    }

    var newFilter = new AndFilter(andFilters).simplify();
    if (newFilter.type !== "true") {
      newQuery.push(jsWithOpperation(newFilter, 'filter'));
    }

    if (prevLayer[0].meta['missingApplies']) {
      var sortedMissingApplies = sortedApplyValues(gatherMissingApplies(prevLayer));
      newQuery = newQuery.concat(sortedMissingApplies.map((apply) => jsWithOpperation(apply, 'apply')));
    }

    var noSegmentFilter = i > 1;
    var condensedCommand: CondensedCommand;
    while (condensedCommand = condensedCommands[i]) {
      if (noSegmentFilter) {
        newQuery.push(jsWithOpperation(condensedCommand.split.withoutSegmentFilter(), 'split'));
      } else {
        newQuery.push(jsWithOpperation(condensedCommand.split, 'split'));
      }
      if (currentLayer.length && prevLayer.every((segment) => Boolean(segment.splits))) {
        sortedMissingApplies = sortedApplyValues(gatherMissingApplies(currentLayer));
        addSortByIfNeeded(sortedMissingApplies, condensedCommand.getSortBy());
        newQuery = newQuery.concat(sortedMissingApplies.map((apply) => jsWithOpperation(apply, 'apply')));
      } else {
        var applySimplifier = new ApplySimplifier(applySimplifierSettings);
        applySimplifier.addApplies(condensedCommand.applies);
        var simpleApplies = applySimplifier.getSimpleApplies();
        addSortByIfNeeded(simpleApplies, condensedCommand.getSortBy());
        newQuery = newQuery.concat(simpleApplies.map((apply) => jsWithOpperation(apply, 'apply')));
      }
      newQuery.push(jsWithOpperation(condensedCommand.combine, 'combine'));

      prevLayer = currentLayer;
      currentLayer = nextLoadingLayer(prevLayer);
      i++;
    }

    return FacetQuery.fromJS(newQuery);
  }

  export interface FractalCacheParameters {
    driver: Driver.FacetDriver;
    keepFor?: number;
    getCurrentTime?: () => number;
    debug?: boolean;
  }

  var totalCacheError = 0;

  export function getTotalCacheError() {
    return totalCacheError;
  }

  interface LayerGroup extends Array<SegmentTree> {
    $_parent?: SegmentTree;
  }

  export function fractalCache(parameters: FractalCacheParameters) {
    var driver = parameters.driver;
    var keepFor = parameters.keepFor;
    var getCurrentTime = parameters.getCurrentTime || (() => Date.now());
    var debug = parameters.debug;

    var applyCache = new LRUCache<ApplyCacheSlot>({
      name: "apply",
      keepFor: keepFor,
      currentTime: getCurrentTime
    });

    var combineToSplitCache = new LRUCache<CombineToSplits>({
      name: "splitCombine",
      keepFor: keepFor,
      currentTime: getCurrentTime
    });

    function cleanCacheProp(prop: Lookup<any>) {
      for (var key in prop) {
        if (key.substring(0, 3) === "c_S") {
          delete prop[key];
        }
      }
    }

    function fillPropFromCache(prop: Lookup<any>, applyHashes: ApplyHash[]) {
      var value: any;
      var missingApplies: Lookup<FacetApply> = null;
      for (var i = 0; i < applyHashes.length; i++) {
        var applyHashVal = applyHashes[i];
        var name = applyHashVal.name;
        var apply = applyHashVal.apply;
        var applyHash = applyHashVal.applyHash;
        var segmentHash = applyHashVal.segmentHash;
        var applyCacheSlot = applyCache.get(segmentHash);
        if (!applyCacheSlot || ((value = applyCacheSlot[applyHash]) == null)) {
          missingApplies || (missingApplies = {});
          missingApplies[applyHash] = apply;
          continue;
        }

        prop[name] = value;
      }
      return missingApplies;
    }

    function constructSegmentProp(segment: SegmentTree, datasetMap: Lookup<FacetDataset>, simpleApplies: FacetApply[], postProcessors: PostProcessor[]) {
      var applyHashes = appliesToHashes(simpleApplies, segment.meta['filter'], datasetMap);
      var segmentProp = segment.prop;
      var missingApplies = fillPropFromCache(segmentProp, applyHashes);
      if (missingApplies) {
        cleanCacheProp(segmentProp);
        segment.markLoading();
        segment.meta['missingApplies'] = missingApplies;
      } else {
        postProcessors.forEach((postProcessor) => postProcessor(segmentProp));
        cleanCacheProp(segmentProp);
      }
    }

    function getQueryDataFromCache(query: FacetQuery) {
      var datasetMap = makeDatasetMap(query);
      var rootSegment = new SegmentTree({
        prop: {}
      }, {
        filter: query.getFilter()
      });

      var condensedCommands = query.getCondensedCommands();
      var currentLayerGroups: LayerGroup[] = [
        [rootSegment]
      ];

      for (var i = 0; i < condensedCommands.length; i++) {
        var condensedCommand = condensedCommands[i];
        var applySimplifier = new ApplySimplifier(applySimplifierSettings);
        applySimplifier.addApplies(condensedCommand.applies);
        var simpleApplies = applySimplifier.getSimpleApplies();
        var postProcessors = applySimplifier.getPostProcessors();
        currentLayerGroups.forEach((layerGroup) => layerGroup.map((segment) => constructSegmentProp(segment, datasetMap, simpleApplies, postProcessors)));
        var combine = <SliceCombine>(condensedCommand.getCombine());
        if (combine) {
          var compareFn = combine.sort.getSegmentCompareFn();
          currentLayerGroups.forEach((layerGroup) => {
            layerGroup.sort(compareFn);
            if (combine.limit != null) {
              driverUtil.inPlaceTrim(layerGroup, combine.limit);
            }
            return layerGroup.$_parent.setSplits(layerGroup);
          });
        }
        var nextCondensedCommand = condensedCommands[i + 1];
        if (nextCondensedCommand) {
          var split = nextCondensedCommand.getEffectiveSplit();
          var splitName = split.name;
          var segmentFilterFn = split.segmentFilter ? split.segmentFilter.getFilterFn() : null;

          var flatLayer = driverUtil.flatten(currentLayerGroups);
          if (segmentFilterFn) {
            flatLayer = flatLayer.filter(segmentFilterFn);
          }
          if (flatLayer.length === 0) {
            break;
          }

          currentLayerGroups = [];
          for (var j = 0; j < flatLayer.length; j++) {
            var segment = flatLayer[j];
            var filterSplitHash = filterSplitToHash(datasetMap, segment.meta['filter'], split);
            var combineToSplitsCacheSlot = combineToSplitCache.get(filterSplitHash);
            var flags: Flags = {};
            var splitValues: any[];
            if (!combineToSplitsCacheSlot || !(splitValues = combineToSplitsCacheSlot.get(segment.meta['filter'], nextCondensedCommand, flags))) {
              if (flags.fullQuery) {
                rootSegment.meta['fullQuery'] = true;
              }
              segment.markLoading();
              continue;
            }

            if (flags.fullQuery) {
              rootSegment.meta['fullQuery'] = true;
            }

            var layerGroup: LayerGroup = splitValues.map((splitValue) => {
              var initProp: Prop = {};
              initProp[splitName] = splitValue;
              var childSegment = new SegmentTree({
                parent: segment,
                prop: initProp
              }, {
                filter: new AndFilter([segment.meta['filter'], split.getFilterFor(initProp)]).simplify()
              });
              return childSegment;
            });

            layerGroup.$_parent = segment;
            currentLayerGroups.push(layerGroup);
          }
        }
      }

      return rootSegment;
    }

    function propToCache(prop: Prop, applyHashes: ApplyHash[]) {
      if (!applyHashes.length) return;
      for (var i = 0; i < applyHashes.length; i++) {
        var applyHashVal = applyHashes[i];
        var name = applyHashVal.name;
        var applyHash = applyHashVal.applyHash;
        var segmentHash = applyHashVal.segmentHash;
        var applyCacheSlot = applyCache.getOrCreate(segmentHash, () => (<ApplyCacheSlot>({})));
        applyCacheSlot[applyHash] = prop[name];
      }
    }

    function saveSegmentProp(segment: SegmentTree, datasetMap: Lookup<FacetDataset>, simpleApplies: FacetApply[]) {
      if (!segment.prop) return;
      var applyHashes = appliesToHashes(simpleApplies, segment.meta['filter'], datasetMap);
      propToCache(segment.prop, applyHashes);
    }

    function saveQueryDataToCache(rootSegment: SegmentTree, query: FacetQuery) {
      var datasetMap = makeDatasetMap(query);
      var condensedCommands = query.getCondensedCommands();
      rootSegment.meta = {
        filter: query.getFilter()
      };
      var currentLayer = [rootSegment];

      for (var i = 0; i < condensedCommands.length; i++) {
        var condensedCommand = condensedCommands[i];
        var applySimplifier = new ApplySimplifier(applySimplifierSettings);
        applySimplifier.addApplies(condensedCommand.applies);
        var simpleApplies = applySimplifier.getSimpleApplies();
        currentLayer.forEach((segment) => saveSegmentProp(segment, datasetMap, simpleApplies));
        var nextCondensedCommand = condensedCommands[i + 1];
        if (nextCondensedCommand) {
          var split = nextCondensedCommand.getEffectiveSplit();
          var splitName = split.name;
          var realSplitBucket = getRealSplit(split).bucket;

          currentLayer = driverUtil.flatten(driverUtil.filterMap(currentLayer, (segment) => {
            if (!segment.splits) return;
            var filter = segment.meta['filter'];
            var filterSplitHash = filterSplitToHash(datasetMap, filter, split);
            var combineToSplitsCacheSlot = combineToSplitCache.getOrCreate(filterSplitHash, () => {
              switch (realSplitBucket) {
                case "identity":
                  return new IdentityCombineToSplitValues();
                case "timePeriod":
                  return new TimePeriodCombineToSplitValues();
                case "continuous":
                  return new ContinuousCombineToSplitValues();
              }
            });

            var splitValues: any[] = [];
            segment.splits.forEach((childSegment) => {
              childSegment.meta = {
                filter: new AndFilter([filter, split.getFilterFor(childSegment.prop)]).simplify()
              };
              return splitValues.push(childSegment.prop[splitName]);
            });

            combineToSplitsCacheSlot.set(filter, nextCondensedCommand, splitValues);
            return segment.splits;
          }));
        }
      }

    }

    var cachedDriver: any = (request: Driver.Request, intermediate: Driver.IntermediateCallback) => {
      var deferred = <Q.Deferred<SegmentTree>>Q.defer();

      if (!request) {
        deferred.reject(new Error("request not supplied"));
        return deferred.promise;
      }
      var context = request.context;
      var query = request.query;
      if (!query) {
        deferred.reject(new Error("query not supplied"));
        return deferred.promise;
      }
      if (!FacetQuery.isFacetQuery(query)) {
        deferred.reject(new Error("query must be a FacetQuery"));
        return deferred.promise;
      }

      var avoidCache = (context && context['dontCache'])
        || query.getSplits().some((split) => split.bucket === "tuple")
        || query.getCombines().some((combine) => combine && !isInstanceOf(combine, SliceCombine));

      if (avoidCache) {
        return driver(request);
      }

      var rootSegment = getQueryDataFromCache(query);
      if (rootSegment.hasLoading() || rootSegment.meta['fullQuery']) {
        if (typeof intermediate === "function") {
          intermediate(rootSegment);
        }
      } else {
        deferred.resolve(rootSegment);
        return deferred.promise;
      }

      var queryFilter = query.getFilter();
      var queryAndFilters = queryFilter.type === "true" ? [] : queryFilter.type === "and" ? (<AndFilter>queryFilter).filters : [queryFilter];
      var readOnlyCache = queryAndFilters.some((filter: FacetFilter) => {
        var type = filter.type;
        return type === "false" || type === "contains" || type === "match" || type === "or";
      });
      if (readOnlyCache) {
        return driver(request);
      }

      if (rootSegment.meta['fullQuery']) {
        return driver({
          query: query,
          context: context
        }).then((fullResult) => {
          saveQueryDataToCache(fullResult, query);
          applyCache.tidy();
          combineToSplitCache.tidy();
          return fullResult;
        });
      } else {
        var deltaQuery = computeDeltaQuery(query, rootSegment);

        return driver({
          query: deltaQuery,
          context: context
        }).then((deltaResult) => {
          saveQueryDataToCache(deltaResult, deltaQuery);

          rootSegment = getQueryDataFromCache(query);
          if (rootSegment.hasLoading()) {
            totalCacheError++;
            if (debug) {
              console.log("stillLoading", rootSegment.valueOf());
              cachedDriver.debug();
              throw new Error("total cache error");
            } else {
              return driver(request);
            }
          } else {
            applyCache.tidy();
            combineToSplitCache.tidy();
            return rootSegment;
          }
        });
      }
    };

    cachedDriver.introspect = (opts: any) => {
      return driver.introspect(opts);
    };

    cachedDriver.clear = () => {
      applyCache.clear();
      combineToSplitCache.clear();
    };

    cachedDriver.stats = () => ({
      applyCache: applyCache.size,
      combineToSplitCache: combineToSplitCache.size
    });

    cachedDriver.debug = () => {
      console.log("fractal cache debug:");
      applyCache.debug();
      combineToSplitCache.debug();
    };

    return cachedDriver;
  }
}