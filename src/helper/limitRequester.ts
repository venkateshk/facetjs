module Facet {
  export module Helper {
    export interface LimitRequesterParameters<T> {
      requester: Requester.FacetRequester<T>;
      limit: number;
    }

    interface QueueItem<T> {
      request: Requester.DatabaseRequest<T>;
      deferred: Q.Deferred<any>;
    }

    export function limitRequesterFactory<T>(parameters: LimitRequesterParameters<T>): Requester.FacetRequester<T> {
      var requester = parameters.requester;
      var limit = parameters.limit || 5;

      if (typeof limit !== "number") throw new TypeError("limit should be a number");

      var requestQueue: Array<QueueItem<T>> = [];
      var outstandingRequests: number = 0;

      function requestFinished(): void {
        outstandingRequests--;
        if (!(requestQueue.length && outstandingRequests < limit)) return;
        var queueItem = requestQueue.shift();
        var deferred = queueItem.deferred;
        outstandingRequests++;
        requester(queueItem.request)
          .then(deferred.resolve, deferred.reject)
          .fin(requestFinished);
      }

      return (request: Requester.DatabaseRequest<T>): Q.Promise<any> => {
        if (outstandingRequests < limit) {
          outstandingRequests++;
          return requester(request).fin(requestFinished);
        } else {
          var deferred = Q.defer();
          requestQueue.push({
            request: request,
            deferred: deferred
          });
          return deferred.promise;
        }
      };
    }
  }
}
