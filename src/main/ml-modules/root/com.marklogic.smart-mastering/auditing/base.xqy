xquery version "1.0-ml";

module namespace auditing = "http://marklogic.com/smart-mastering/auditing";

import module namespace diff = "http://marklogic.com/demo/xml-diff"
  at "/mlpm_modules/marklogic-xml-diff/diff.xqy";
import module namespace mem = "http://maxdewpoint.blogspot.com/memory-operations/functional"
  at "/mlpm_modules/XQuery-XML-Memory-Operations/memory-operations-functional.xqy";
import module namespace sem = "http://marklogic.com/semantics"
  at "/MarkLogic/semantics.xqy";


import module namespace xq3 = "http://maxdewpoint.blogspot.com/xq3-ml-extensions"
  at "/mlpm_modules/xq3-ml-extensions/xq3.xqy";

import module namespace const = "http://marklogic.com/smart-mastering/constants"
  at "/com.marklogic.smart-mastering/constants.xqy";

declare namespace prov = "http://www.w3.org/ns/prov#";
declare namespace foaf = "http://xmlns.com/foaf/0.1/";
declare namespace sm = "http://marklogic.com/smart-mastering/auditing#";
declare namespace rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace rdfs = "http://www.w3.org/2000/01/rdf-schema#";

declare variable $auditing:UPDATE-ACTION := "update";
declare variable $auditing:ROLLBACK-ACTION := "rollback";

declare variable $prov-prefix := fn:namespace-uri-from-QName(xs:QName("prov:document"));
declare variable $foaf-prefix := fn:namespace-uri-from-QName(xs:QName("foaf:document"));
declare variable $sm-prefix := fn:namespace-uri-from-QName(xs:QName("sm:document"));
declare variable $rdf-prefix := fn:namespace-uri-from-QName(xs:QName("rdf:document"));
declare variable $rdfs-prefix := fn:namespace-uri-from-QName(xs:QName("rdfs:document"));

declare variable $RDF-TYPE-IRI := sem:iri($rdf-prefix || "type");
declare variable $RDFS-LABEL-IRI := sem:iri($rdfs-prefix || "label");

declare function auditing:audit-trace(
  $action,
  $previous-uris,
  $new-uri,
  $attachments
)
{
  let $dateTime := fn:current-dateTime()
  let $username := xdmp:get-current-user()
  let $new-entity-id := $sm-prefix||$new-uri
  let $activity-id := ($sm-prefix||$action||"-"||$new-uri || "-" || xdmp:request())
  let $user-id := ($sm-prefix||"user-"||$username)
  let $attribution-id := ($sm-prefix||"attribution-"||$username||"-"||sem:uuid-string())
  let $prov-xml :=
    element { xs:QName("prov:document") } {
      namespace foaf {$foaf-prefix},
      namespace prov {$prov-prefix},
      namespace sm {$sm-prefix},
      namespace xsd {"http://www.w3.org/2001/XMLSchema"},
      element auditing:new-uri { $new-uri },
      $previous-uris ! element auditing:previous-uri { . },
      element {fn:QName($prov-prefix, "activity")} {
        attribute {fn:QName($prov-prefix, "id")} {
          $activity-id
        },
        element {fn:QName($prov-prefix, "type")} {
          attribute xsi:type {"xsd:string"},
          $action
        },
        element {fn:QName($prov-prefix, "label")} {
          $action || " by " || $username
        }
      },
      let $previous-entities :=
        for $previous-uri in $previous-uris
        return (
          element {fn:QName($prov-prefix, "collection")} {
            attribute {fn:QName($prov-prefix, "id")} {
              $sm-prefix||$previous-uri
            },
            element {fn:QName($prov-prefix, "type")} {
              attribute xsi:type {"xsd:string"},
              "contributing record for " || $action
            },
            element {fn:QName($prov-prefix, "label")} {$previous-uri}
          }
        )
      let $new-entity :=
        element {fn:QName($prov-prefix, "collection")} {
          attribute {fn:QName($prov-prefix, "id")} {
            $sm-prefix||$new-uri
          },
          element {fn:QName($prov-prefix, "type")} {
            attribute xsi:type {"xsd:string"},
            "result of record " || $action
          },
          element {fn:QName($prov-prefix, "label")} {$new-uri}
        }
      return (
        $previous-entities,
        $new-entity,
        for $previous-entity in $previous-entities
        return
          element {fn:QName($prov-prefix, "wasDerivedFrom")} {
            element {fn:QName($prov-prefix, "generatedEntity")} {
              attribute {fn:QName($prov-prefix, "ref")} {
                $new-entity-id
              }
            },
            element {fn:QName($prov-prefix, "usedEntity")} {
              attribute {fn:QName($prov-prefix, "ref")} {
                fn:string($previous-entity/@*:id)
              }
            },
            element {fn:QName($prov-prefix, "activity")} {
              attribute {fn:QName($prov-prefix, "ref")} {
                $activity-id
              }
            }
          }
      ),
      element {fn:QName($prov-prefix, "agent")} {
        attribute {fn:QName($prov-prefix, "id")} {
          $user-id
        },
        element {fn:QName($prov-prefix, "type")} {
          attribute xsi:type {"xsd:QName"},
          "foaf:OnlineAccount"
        },
        element {fn:QName($foaf-prefix, "accountName")} {$username}
      },
      element {fn:QName($prov-prefix, "wasAttributedTo")} {
        element {fn:QName($prov-prefix, "entity")} {
          attribute {fn:QName($prov-prefix, "ref")} {
            $new-entity-id
          }
        },
        element {fn:QName($prov-prefix, "agent")} {
          attribute {fn:QName($prov-prefix, "ref")} {
            $user-id
          }
        }
      },
      element {fn:QName($prov-prefix, "wasGeneratedBy")} {
        element {fn:QName($prov-prefix, "entity")} {
          attribute {fn:QName($prov-prefix, "ref")} {
            $new-entity-id
          }
        },
        element {fn:QName($prov-prefix, "activity")} {
          attribute {fn:QName($prov-prefix, "ref")} {
            $activity-id
          }
        },
        element {fn:QName($prov-prefix, "time")} {
          $dateTime
        }
      },
      $attachments
    }
  return
    xdmp:document-insert(
      "/com.marklogic.smart-mastering/auditing/"|| $action ||"/"||sem:uuid-string()||".xml",
      element {fn:QName($prov-prefix, "document")} {
        $prov-xml/node(),
        auditing:build-semantic-info($prov-xml)
      },
      (
        xdmp:default-permissions(),
        xdmp:permission($const:MDM-USER, "read"),
        xdmp:permission($const:MDM-ADMIN, "update")
      ),
      $const:AUDITING-COLL
    )
};

declare function auditing:auditing-receipts-for-doc-uri($doc-uri)
{
  cts:search(fn:collection($const:AUDITING-COLL)/prov:document,
    cts:element-value-query(
      xs:QName("auditing:new-uri"),
      $doc-uri,
      "exact"
    )
  )
};

declare function auditing:auditing-receipts-for-doc-history($doc-uri)
{
  auditing:auditing-receipts-for-doc-history(
    $doc-uri,
    ()
  )
};

declare function auditing:auditing-receipts-for-doc-history($doc-uris, $returned-docs)
{
  if (fn:exists($doc-uris)) then
    cts:search(fn:collection($const:AUDITING-COLL)/prov:document,
      cts:and-query((
        cts:element-value-query(
          (
            xs:QName("auditing:previous-uri"),
            xs:QName("auditing:new-uri")
          ),
          $doc-uris,
          "exact"
        ),
        cts:not-query(cts:document-query($returned-docs ! xdmp:node-uri(.)))
      ))
    )
  else
    $returned-docs
};

declare function auditing:audit-trace-rollback($prov-xml)
{
  let $merged-uri :=
    fn:string(
      $prov-xml/prov:collection[fn:starts-with(prov:type, "result of record ")]/prov:label
    )
  for $entity in $prov-xml/prov:collection[fn:starts-with(prov:type, "contributing record for ")]
  let $orig-uri :=
    fn:string(
      $entity/prov:label
    )
  return
    auditing:audit-trace(
      $auditing:ROLLBACK-ACTION,
      $merged-uri,
      $orig-uri,
      ()
    )
};

declare function auditing:_build-agent-triples(
  $agent-iri as sem:iri,
  $username as xs:string,
  $software-agents as element(prov:softwareAgent)*
) as sem:triple*
{
  if (auditing:subject-not-stored(fn:string($agent-iri))) then (
    sem:triple(
      $agent-iri,
      $RDF-TYPE-IRI,
      sem:iri($foaf-prefix||"OnlineAccount")
    ),
    sem:triple(
      $agent-iri,
      sem:iri($foaf-prefix||"accountName"),
      $username
    ),
    sem:triple(
      $agent-iri,
      $RDFS-LABEL-IRI,
      $username
    )
  ) else (),
  for $software-agent in $software-agents
  let $iri := sem:iri($software-agent/@prov:id)
  where auditing:subject-not-stored(fn:string($iri))
  return (
    sem:triple(
      $iri,
      $RDF-TYPE-IRI,
      sem:iri($prov-prefix||"SoftwareAgent")
    ),
    sem:triple(
      $iri,
      $RDFS-LABEL-IRI,
      fn:string($software-agent/prov:label)
    ),
    sem:triple(
      $iri,
      sem:iri($prov-prefix||"atLocation"),
      fn:string($software-agent/prov:location)
    )
  )
};

declare function auditing:_build-prov-o-triples(
  $agent as element(prov:agent),
  $activity as element(prov:activity),
  $dateTime as xs:dateTime,
  $entities as element()*,
  $influences as element(prov:wasInfluencedBy)*
)
{
  let $agent-iri := sem:iri(fn:string($agent/@prov:id))
  let $username := fn:string($agent/foaf:accountName)
  let $attribution-iri := sem:iri($sm-prefix||"attribution-"||$username||"-"||sem:uuid-string())
  let $activity-iri := sem:iri(fn:string($activity/@prov:id))
  let $action := fn:string($activity/prov:type)
  let $previous-entities := $entities[fn:starts-with(prov:type, "contributing record for ")]
  let $new-entity := $entities[fn:starts-with(prov:type, "result of record ")]
  let $new-entity-iri := sem:iri(fn:string($new-entity/@prov:id))
  return (
    element sem:triples {
      sem:triple(
        $attribution-iri,
        $RDF-TYPE-IRI,
        sem:iri($prov-prefix||"Attribution")
      ),
      sem:triple(
        $attribution-iri,
        sem:iri($prov-prefix||"agent"),
        $agent-iri
      ),
      sem:triple(
        $attribution-iri,
        $RDF-TYPE-IRI,
        "authorship"
      ),
      sem:triple(
        $activity-iri,
        $RDF-TYPE-IRI,
        sem:iri($prov-prefix||"Activity")
      ),
      sem:triple(
        $activity-iri,
        $RDFS-LABEL-IRI,
        $action || " by " || $username
      ),
      sem:triple(
        $activity-iri,
        sem:iri($prov-prefix||"atTime"),
        $dateTime
      ),
      sem:triple(
        $activity-iri,
        sem:iri($prov-prefix||"wasAssociatedWith"),
        $agent-iri
      ),
      sem:triple(
        $new-entity-iri,
        sem:iri($prov-prefix||"wasGeneratedBy"),
        $activity-iri
      ),
      for $influence in $influences
      return (
        sem:triple(
          sem:iri($influence/prov:influencee/@prov:ref),
          sem:iri($prov-prefix||"wasInfluencedBy"),
          sem:iri($influence/prov:influencer/@prov:ref)
        ),
        sem:triple(
          sem:iri($influence/prov:influencer/@prov:ref),
          sem:iri($prov-prefix||"influenced"),
          sem:iri($influence/prov:influencee/@prov:ref)
        )
      ),
      for $previous-entity in $previous-entities
      let $previous-entity-iri := sem:iri(fn:string($previous-entity/@prov:id))
      return (
        sem:triple(
          $new-entity-iri,
          sem:iri($prov-prefix||"wasDerivedFrom"),
          $previous-entity-iri
        ),
        sem:triple(
          $previous-entity-iri,
          sem:iri($prov-prefix||"wasInvalidatedBy"),
          $activity-iri
        )
      ),
      sem:triple(
        $new-entity-iri,
        sem:iri($prov-prefix||"wasAttributedTo"),
        $agent-iri
      )
    }
  )
};

(:
 : Construct triples to capture auditing record. Some of these will be inserted immediately as managed triples,
 : others will be returned.
 :)
declare function auditing:build-semantic-info($prov-xml as element(prov:document))
{
  let $dateTime := $prov-xml/prov:wasGeneratedBy/prov:time ! xs:dateTime(.)
  let $agent := $prov-xml/prov:agent
  let $agent-iri := sem:iri(fn:string($agent/@prov:id))
  let $username := fn:string($agent/foaf:accountName)
  let $activity := $prov-xml/prov:activity
  let $entities := $prov-xml//(prov:collection|prov:entity|prov:bundle)[fn:exists(@prov:id)]
  let $auditing-managed-triples := (
    _build-agent-triples($agent-iri, $username, $prov-xml/prov:softwareAgent),
    for $entity in $entities
    return
      auditing:_build-entity-managed-triples($entity, $prov-xml)
  )
  return (
    if (fn:exists($auditing-managed-triples)) then
      sem:graph-insert(
        sem:iri("mdm-auditing"),
        $auditing-managed-triples,
        (
          xdmp:default-permissions(),
          xdmp:permission($const:MDM-USER, "read"),
          xdmp:permission($const:MDM-ADMIN, "update")
        ),
        $const:AUDITING-COLL
      )
    else (),
    auditing:_build-prov-o-triples($agent, $activity, $dateTime, $entities, $prov-xml/prov:wasInfluencedBy)
  )
};

declare function auditing:_build-entity-managed-triples($entity, $prov-xml)
{
  let $entity-id := fn:string($entity/@prov:id)
  let $entity-iri := sem:iri($entity-id)
  let $collection-members := $prov-xml/prov:hadMember[prov:collection/@prov:ref = $entity-id]
  return
    if (auditing:subject-not-stored($entity-id)) then (
      if ($entity instance of element(prov:collection)) then (
        let $collection-members := $prov-xml/prov:hadMember[prov:collection/@prov:ref = $entity-id]
        for $member-id in $collection-members/prov:entity/(@prov:ref|@prov:id)
        return
          sem:triple(
            $entity-iri,
            sem:iri($prov-prefix||"hadMember"),
            sem:iri($member-id)
          ),
        sem:triple(
          $entity-iri,
          $RDF-TYPE-IRI,
          sem:iri($prov-prefix||"Collection")
        )
      ) else (),
      sem:triple(
        $entity-iri,
        $RDF-TYPE-IRI,
        sem:iri($prov-prefix||"Entity")
      ),
      sem:triple(
        $entity-iri,
        sem:iri($sm-prefix||"document-uri"),
        fn:string($entity/prov:label)
      ),
      sem:triple(
        $entity-iri,
        $RDFS-LABEL-IRI,
        fn:string($entity/prov:label)
      )
    ) else ()
};


declare function auditing:reverse-change-set($node as node())
{
  typeswitch ($node)
  case element(diff:addition) return
    element diff:removal {
      $node/@*,
      fn:map(auditing:reverse-change-set#1, $node/node())
    }
  case element(diff:removal) return
    element diff:addition {
      $node/@*,
      fn:map(auditing:reverse-change-set#1, $node/node())
    }
  case element() return
    element {fn:node-name($node)} {
      fn:map(auditing:reverse-change-set-attributes#1,$node/@*),
      fn:map(auditing:reverse-change-set#1, $node/node())
    }
  default return
    $node
};

declare function auditing:reverse-change-set-attributes($node as attribute())
{
  typeswitch ($node)
  case attribute(diff:addition) return
    attribute diff:removal {
      fn:string($node)
    }
  case attribute(diff:removal) return
    attribute diff:addition {
      fn:string($node)
    }
  default return
    $node
};

declare function auditing:subject-not-stored($iri-str) as xs:boolean
{
  xdmp:estimate(
    cts:search(
      fn:collection($const:AUDITING-COLL),
      cts:element-value-query(
        xs:QName("sem:subject"),
        $iri-str,
        "exact"
      )
    ),
    1
  ) = 0
};

