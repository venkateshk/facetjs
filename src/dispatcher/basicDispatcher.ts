module Facet {
  export interface Dispatcher {
    (ex: Expression): Q.Promise<NativeDataset>;
  }

  export interface BasicDispatcherParameters {
    context: Datum;
  }

  export function basicDispatcherFactory(parameters: BasicDispatcherParameters): Dispatcher {
    var context = parameters.context;
    return (ex: Expression) => {
      return ex.compute(context);
    }
  }
}
