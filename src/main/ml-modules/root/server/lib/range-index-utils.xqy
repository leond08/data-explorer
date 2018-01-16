xquery version "1.0-ml";

module namespace riu = "http://marklogic.com/data-explore/lib/range-index-utils";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace cfg = "http://www.marklogic.com/data-explore/lib/config" at "/server/lib/config.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-nodoc-2007-01.xqy";

declare namespace db = "http://marklogic.com/xdmp/database";


declare function riu:get-indexes($database as xs:string)
as node()* 
{
  (: maybe cache this later on (if too expensive)? :)
  let $admin-config := admin:get-configuration()
  return <range-indexes>{ admin:database-get-range-element-indexes($admin-config, xdmp:database($database)) }</range-indexes>
};

declare function riu:form-field-to-qname($form-field as xs:string)
as xs:QName*
{
  let $ns := cfg:getNamespaceUri(fn:substring-before($form-field, ":"))
  let $localname := fn:substring-after($form-field, ":")
  return fn:QName($ns, $localname)
};

declare function riu:get-index($database as xs:string, $form-field as xs:string)
as node()* 
{
  let $indexes := riu:get-indexes($database)
  let $qname := riu:form-field-to-qname($form-field)
  return fn:head($indexes/db:range-element-index[db:namespace-uri eq fn:namespace-uri-from-QName($qname) 
    and db:localname eq fn:local-name-from-QName($qname)])
};

declare function riu:match-index-values($match-text as xs:string*, $database as xs:string, $form-field as xs:string, $limit as xs:integer*)
as xs:anyAtomicType*
{
  let $max-items := fn:max(($limit, 10)[1], 1)
  let $qtext := functx:trim($match-text)
  let $index := riu:get-index($database, $form-field)

  return xdmp:invoke-function(function() {
    cts:element-value-match(
      riu:form-field-to-qname($form-field),
      if (fn:string-length($qtext) gt 0) then fn:concat("*", $match-text, "*") else "*",
      (
        "case-insensitive", "frequency-order",
        fn:concat("limit=", $max-items),
        fn:concat("collation=", $index/db:collation/fn:string())
      )
    )
  },
  <options xmlns="xdmp:eval">
    <database>{ xdmp:database($database) }</database>
  </options>)
};