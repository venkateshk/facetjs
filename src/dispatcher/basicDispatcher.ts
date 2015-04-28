module Facet {
  export interface Dispatcher {
    (ex: Expression): Q.Promise<NativeDataset>;
  }

  interface BasicDispatcherParameters {
    context: Datum;
  }

  function basicDispatcherFactory(parameters: BasicDispatcherParameters): Dispatcher {
    var context = parameters.context;
    return (ex: Expression) => {
      return ex.compute(context);
    }
  }
}
