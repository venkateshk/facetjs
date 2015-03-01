module Core {
  export interface Capabilety {
    (ex: Expression): boolean;
  }

  export interface FilterCapabileties {
    canIs?: Capabilety;
    canAnd?: Capabilety;
    canOr?: Capabilety;
    canNot?: Capabilety;
  }

  export interface ApplyCombineCapabileties {
    canSum?: Capabilety;
    canMin?: Capabilety;
    canMax?: Capabilety;
    canGroup?: Capabilety;
  }

  export interface SplitCapabileties {
    canTotal?: ApplyCombineCapabileties;
    canSplit?: ApplyCombineCapabileties;
  }

  export interface DatastoreQuery {
    query: any;
    post: (result: any) => Q.Promise<Dataset>;
  }

  export module druidDriver {
    function filterToDruid(ex: Expression): Druid.Filter {

    }

    function makeQuery(ex: Expression): DatastoreQuery {
      throw new Error("make me");
    }
  }
}
