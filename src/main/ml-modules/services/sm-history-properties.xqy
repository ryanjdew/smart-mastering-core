xquery version "1.0-ml";

module namespace resource = "http://marklogic.com/rest-api/resource/sm-history-properties";

import module namespace history = "http://marklogic.com/smart-mastering/auditing/history"
  at "/com.marklogic.smart-mastering/auditing/history.xqy";

declare function get(
  $context as map:map,
  $params  as map:map
  ) as document-node()*
{
  let $results := history:property-history(map:get($params,"uri"),  map:get($params,"property"))
  return
    xdmp:to-json($results)
};
