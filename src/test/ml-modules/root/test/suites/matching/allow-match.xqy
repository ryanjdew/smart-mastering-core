xquery version "1.0-ml";

import module namespace matcher = "http://marklogic.com/smart-mastering/matcher"
  at "/com.marklogic.smart-mastering/matcher.xqy";

import module namespace test = "http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";

(: Force update mode :)
declare option xdmp:update "true";

declare option xdmp:mapping "false";

let $assertions := ()
let $uri1 := "/content1.xml"
let $uri2 := "/content2.xml"

(: setup.xqy creates a block. Remove it. :)
let $_ :=
  xdmp:invoke-function(
    function() { matcher:allow-match($uri2, $uri1) },
    <options xmlns="xdmp:eval">
      <isolation>different-transaction</isolation>
    </options>
  )

(: Blocks should be gone :)
let $assertions := (
  $assertions,
  test:assert-not-exists(matcher:get-blocks($uri1)/node()),
  test:assert-not-exists(matcher:get-blocks($uri2)/node())
)

return $assertions
