module Legacy {
  export interface AjaxParameters {
    url: string;
    context: Lookup<any>;
    pretty: boolean;
  }

  export function ajax(parameters: AjaxParameters) {
    var url = parameters.url;
    var posterContext = parameters.context;
    var pretty = parameters.pretty;

    return (request: Driver.Request, callback: Driver.DataCallback) => {
      var query = request.query;
      if (!FacetQuery.isFacetQuery(query)) {
        throw new TypeError("query must be a FacetQuery");
      }

      var context = request.context || {};
      for (var k in posterContext) {
        if (!posterContext.hasOwnProperty(k)) continue;
        context[k] = posterContext[k];
      }

      return jQuery.ajax({
        url: url,
        type: "POST",
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify({
          context: context,
          query: query.valueOf()
        }, null, pretty ? 2 : null),
        success: (res) => {
          callback(null, new SegmentTree(res));
        },
        error: (xhr) => {
          var err: any;
          var text = xhr.responseText;
          try {
            err = JSON.parse(text);
          } catch (e) {
            err = {
              message: text
            };
          }
          callback(err, null);
        }
      });
    };
  }
}
