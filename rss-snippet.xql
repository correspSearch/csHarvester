xquery version "3.1";

import module namespace csharv="https://correspSearch.net/harvester" at "modules/harvester.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

let $url := request:get-parameter('url', ())

let $cmif-file := collection($csharv:data)//tei:TEI[.//tei:idno/matches(normalize-space(.), $url)]

let $items :=
    for $bibl in $cmif-file//tei:bibl
    let $title := substring-before($bibl/text(), '.')
    let $description := $bibl//text()
    let $guid := $bibl/@xml:id/data(.)
    let $pubDate :=  format-dateTime(current-dateTime(), '[D] [MNn, 0-3] [Y] [H]:[m]:[s]')
    return
   (<item>
        <title>New: {$title}</title>
        <description>{$description}</description>
        <link>https://correspsearch.net/de/suche.html?e={$guid}</link>
        <guid>{$guid}</guid>
        <pubDate>{$pubDate} +01:00</pubDate>
    </item>,
    <twitter>
        Neu in correspSearch: {$description} https://correspsearch.net/de/suche.html?e={$guid}
    </twitter>)

return
element rss-snippet {
    $items
}