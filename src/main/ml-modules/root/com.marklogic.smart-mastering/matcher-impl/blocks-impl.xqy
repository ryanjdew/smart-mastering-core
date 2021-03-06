xquery version "1.0-ml";

(:
 : This is an implementation library, not an interface to the Smart Mastering functionality.
 :)

module namespace blocks-impl = "http://marklogic.com/smart-mastering/blocks-impl";

import module namespace const = "http://marklogic.com/smart-mastering/constants"
  at "/com.marklogic.smart-mastering/constants.xqy";
import module namespace sem = "http://marklogic.com/semantics"
  at "/MarkLogic/semantics.xqy";

declare option xdmp:mapping "false";

(:
 : Return a JSON array of any URIs the that input URI is blocked from matching.
 : @param $uri  input URI
 : @return JSON array of URIs
 :)
declare function blocks-impl:get-blocks($uri as xs:string)
  as array-node()
{
  let $solution :=
    sem:sparql(
      "select distinct(?uri as ?blocked) where { ?uri ?isBlocked ?target }",
      map:new((
        map:entry("target", sem:iri($uri)),
        map:entry("isBlocked", $const:PRED-MATCH-BLOCK)
      )),
      "map"
    )
  return
    array-node {
      if (fn:exists($solution)) then
        $solution ! fn:string(map:get(., "blocked"))
      else ()
    }
};

(:
 : Block all pairs of URIs from matching.
 : No return type specified to allow tail call optimization.
 :
 : @param uris the sequence of URIs
 : @return empty sequence
 :)
declare function blocks-impl:block-matches($uris as xs:string*)
{
  if (fn:empty($uris) or fn:count($uris) = 1) then
  (: We're done :)
    ()
  else
    let $tail := fn:tail($uris)
    let $_ := $tail ! blocks-impl:block-match(fn:head($uris), .)
    return blocks-impl:block-matches($tail)
};

(:
 : Prevent the two input URIs from being allowed to match. Helper function for block-matches.
 :
 : @param $uri1  First input URI
 : @param $uri2  Second input URI
 : @error will throw xs:QName("SM-CANT-BLOCK") if unable to record the block.
 : @return empty sequence
 :)
declare function blocks-impl:block-match($uri1 as xs:string, $uri2 as xs:string)
as empty-sequence()
{
  let $_ :=
    (: Suppress sem:rdf-insert's return value :)
    sem:rdf-insert(
      (
        sem:triple(sem:iri($uri1), $const:PRED-MATCH-BLOCK, sem:iri($uri2)),
        sem:triple(sem:iri($uri2), $const:PRED-MATCH-BLOCK, sem:iri($uri1))
      )
    )
  return ()
};

(:
 : Clear a match block between the two input URIs.
 :
 : @param $uri1  First input URI
 : @param $uri2  Second input URI
 :
 : @error will throw xs:QName("SM-CANT-UNBLOCK") if a block is present, but it cannot be cleared
 : @return  fn:true if a block was found and cleared; fn:false if no block was found
 :)
declare function blocks-impl:allow-match($uri1 as xs:string, $uri2 as xs:string)
{
  sem:database-nodes((
    cts:triples(sem:iri($uri1), $const:PRED-MATCH-BLOCK, sem:iri($uri2)),
    cts:triples(sem:iri($uri2), $const:PRED-MATCH-BLOCK, sem:iri($uri1))
  )) ! xdmp:node-delete(.)
};

