xquery version "3.1";

module namespace app="https://correspSearch.net/apps/harvester/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="https://correspSearch.net/apps/harvester/config" at "config.xqm";
import module namespace csharv="https://correspSearch.net/harvester" at "harvester.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~
 : This is a sample templating function. It will be called by the templating module if
 : it encounters an HTML element with an attribute: data-template="app:test" or class="app:test" (deprecated). 
 : The function has to take 2 default parameters. Additional parameters are automatically mapped to
 : any matching request or function parameter.
 : 
 : @param $node the HTML node with the attribute which triggered this call
 : @param $model a map containing arbitrary data - used to pass information between template calls
 :)


(: form actions :)

declare function app:actions($node as node(), $model as map(*)) as map(*) {
let $id := request:get-parameter('id', ())
let $url := request:get-parameter('url', ())

let $result :=
    if ($id='update-all')
    then csharv:update-all()
    else if ($id='update')
    then csharv:update($url)
    else if ($id='clear-log')
    then csharv:clear-log()
    else if ($id='register-retrieve')
    then (csharv:register-retrieve($url))
    else if ($id='register')
    then csharv:register($url)
    else if ($id='deregister')
    then csharv:deregister($url)
    else if ($id='disable')
    then csharv:disable($url)
    else if ($id='enable')
    then csharv:enable($url)
    else if ($id='clear-reports')
    then csharv:clear-reports()
    else ()

return
    map { "result" : $result }
};

declare function app:action-alert-update($node as node(), $model as map(*)) {
    let $id := request:get-parameter('id', ())
    return
    if (not($id='register' or $id='register-retrieve'))
    then app:action-alert($node, $model)
    else ()
};

declare function app:action-alert-register($node as node(), $model as map(*)) {
    let $id := request:get-parameter('id', ())
    return
    if ($id='register' or $id='register-retrieve')
    then app:action-alert($node, $model)
    else ()
};

declare function app:action-alert($node as node(), $model as map(*)) as node()* {
     for $result in $model("result") 
     let $type :=  $result/@type/data(.)
     let $message := $result
     return
     if ($type eq 'success') then
         <div class="alert alert-success" role="alert">{$message}</div>
     else if ($type eq 'status') then
         <div class="alert alert-secondary" role="alert">{$message}</div>
     else if ($type eq 'error') then
         <div class="alert alert-danger" role="alert">{$message}</div>
     else ()
};

(: Helper Functions :) 

declare function app:format-date($date as xs:string*, $type as xs:string) as xs:string {
    let $pattern := 
        if ($type='all')
        then '[Y0001]-[M01]-[D01], [H01]:[m01]'
        else if ($type='time')
        then '[H01]:[m01]'
        else '[Y0001]-[M01]-[D01]'

    return
    if (matches($date, '^\d\d\d\d-\d\d-\d\d$'))
    then format-date($date, '[Y0001]-[M01]-[D01]')
    else if (matches($date, '^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?([\+|-]\d\d:\d\d|Z)?$'))
    then format-dateTime($date, $pattern)
    else ('—')
};

(: Home Page :)

declare %templates:wrap function app:last-actions($node as node(), $model as map(*)) as map(*) {
    map { "actions" := 
           (for $action at $pos in doc($config:data-root||'/logs/log.xml')//action
            order by $action/start/@timestamp descending
            return
            $action)[position() < 7]
    }
};

declare %templates:wrap function app:last-registered($node as node(), $model as map(*)) as map(*) {
    map { "files" := 
           (for $file in $csharv:cmif-file-index//file
            order by $file/@added-when descending
            return
            $file)[position() < 6]
    }
};

declare %templates:wrap function app:last-modified($node as node(), $model as map(*)) as map(*) {
    map { "teis" := 
            for $file in collection($csharv:data)//tei:TEI[position() < 10]
            order by $file//tei:publicationStmt/tei:date/@when descending
            return
            $file
    }
};

declare %templates:wrap function app:last-modified-date($node as node(), $model as map(*)) {
    let $date := $model("tei")//tei:publicationStmt/tei:date/@when/data(.)
    return
        app:format-date($date, 'date')
};

declare %templates:wrap function app:last-modified-title($node as node(), $model as map(*)) {
    let $title := $model("tei")//tei:titleStmt/tei:title/normalize-space(.)
    let $url := $model("tei")//tei:publicationStmt/tei:idno/normalize-space(.)
    return
        element a {
            attribute href { $url },
            $title
        }
};


declare function app:stat($node as node(), $model as map(*)) as element() {
    let $files := count(collection($csharv:data)//tei:TEI)
    let $correspDesc := count(collection($csharv:data)//tei:correspDesc)
    let $bibl := count(collection($csharv:data)//tei:bibl)
    let $publishers := count(distinct-values(collection($csharv:data)//tei:publisher//@target))
    let $last-update-all := $csharv:log//action/start[@type='update-all'][last()]/@timestamp
    return
    <table class="table">
        <tr>
            <td>Files</td>
            <td>{$files}</td>
        </tr>
        <tr>
            <td>correspDesc</td>
            <td>{$correspDesc}</td>
        </tr>
       <tr>
            <td>Publications</td>
            <td>{$bibl}</td>
        </tr>
        <tr>
            <td>Publishers</td>
            <td>{$publishers}</td>
        </tr>
        <tr>
            <td>Last Update All</td>
            <td>{app:format-date($last-update-all, 'all')}</td>
        </tr>
    </table>
};

(: Log of Actions :)

declare %templates:wrap function app:log-actions($node as node(), $model as map(*)) as map(*) {
    map { "actions" := 
            for $action in doc($config:data-root||'/logs/log.xml')//action
            order by $action/start/@timestamp descending
            return
            $action
    }
};

declare %templates:wrap function app:log-action-id($node as node(), $model as map(*)) {
    element a { 
        attribute href { 'action.html?id='||$model("action")/@id/data(.) }, 
        element i {
            attribute class {'fas fa-file-alt fa-lg'}
        }
    }
};

declare %templates:wrap function app:log-action-date($node as node(), $model as map(*)) {
    app:format-date($model("action")/start/@timestamp/data(.), 'date')
};

declare %templates:wrap function app:log-action-time($node as node(), $model as map(*)) {
    app:format-date($model("action")/start/@timestamp/data(.), 'time')
};

declare %templates:wrap function app:log-action-type($node as node(), $model as map(*)) {
    $model("action")/start/@type/data(.)
};

declare %templates:wrap function app:log-action-urls($node as node(), $model as map(*)) {
    $model("action")/end/@urls/data(.)
};

declare %templates:wrap function app:log-action-updated($node as node(), $model as map(*)) {
    $model("action")/end/@updated/data(.)
};

declare %templates:wrap function app:log-action-errors($node as node(), $model as map(*)) {
    $model("action")/end/@errors/data(.)
};

declare %templates:wrap function app:log-action-notModified($node as node(), $model as map(*)) {
    $model("action")/end/@notModified/data(.)
};

declare %templates:wrap function app:log-action-loglevel($node as node(), $model as map(*)) {
    $model("action")/start/@loglevel/data(.)
};

declare %templates:wrap function app:log-action-validation-mode($node as node(), $model as map(*)) {
    $model("action")/start/@validation-mode/data(.)
};

declare %templates:wrap function app:log-action-force-update($node as node(), $model as map(*)) {
    $model("action")/start/@force-update/data(.)
};


(: Single action :)

declare %templates:wrap function app:action-entries($node as node(), $model as map(*), $id as xs:string) as map(*) {
    map { "entries" := collection($config:data-root)//action[@id=$id]/* }
};

declare %templates:wrap function app:action-entry-type($node as node(), $model as map(*)) {
    $model("entry")/name()
};

declare %templates:wrap function app:action-entry-url($node as node(), $model as map(*)) {
    $model("entry")/@url/data(.)
};

declare %templates:wrap function app:action-entry-date($node as node(), $model as map(*)) {
    app:format-date($model("entry")/@timestamp/data(.), 'date')
};

declare %templates:wrap function app:action-entry-time($node as node(), $model as map(*)) {
    app:format-date($model("entry")/@timestamp/data(.), 'time')
};

declare function local:view-validation-report($node as node(), $model as map(*)) {
    element table {
        attribute class { 'table' },
        element tr {
            element th {'Line'},
            element th {'Message'}
        },
        for $row in ($model("entry")//message, $model("result")//message) 
        return
        element tr {
            element td { $row/@line/data(.) },
            element td { $row/text() }
        }
     }
};

declare %templates:wrap function app:action-entry-desc($node as node(), $model as map(*)) {
    if ($model("entry")/message)
    then local:view-validation-report($node, $model)
    else $model("entry")/text()
};

(: Registered CMIF files :)

declare %templates:wrap function app:cmif-files($node as node(), $model as map(*)) as map(*) {
    map { "files" := doc($config:app-root||'/data/cmif-file-index.xml')//file }
};

declare %templates:wrap function app:cmif-file-url($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    return
    element a {
        attribute href { $url },
        $url }
};

declare %templates:wrap function app:cmif-file-title($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    let $title := collection($config:data-root)//tei:TEI[.//tei:idno/normalize-space(.)=$url]//tei:titleStmt/tei:title/text()
    return
    if ($title)
    then 
        element a {
            attribute href { $url },
            $title 
        }
    else ('-')
};

declare %templates:wrap function app:cmif-file-count($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    let $count := count(collection($config:data-root)//tei:TEI[.//tei:idno/normalize-space(.)=$url]//tei:correspDesc)
    return
    if ($count)
    then $count
    else ('-')
};

declare %templates:wrap function app:cmif-file-when($node as node(), $model as map(*)) {
    app:format-date($model("file")/@added-when/data(.), 'date')
};

declare %templates:wrap function app:cmif-file-by($node as node(), $model as map(*)) {
    $model("file")/@added-by/data(.)
};

declare %templates:wrap function app:cmif-file-modified($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    let $date := collection($csharv:data)//tei:publicationStmt[.//tei:idno/normalize-space(.)=$url]/tei:date/@when     
    return
    app:format-date($date, 'date')
};

declare %templates:wrap function app:cmif-file-harvested($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    let $date := collection($csharv:cmif-file-index)//file[@url=$url]/@last-harvested/data(.) 
    return
        app:format-date($date, 'all')
};

declare %templates:wrap function app:cmif-file-action-update($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    return
    <a href="?id=update&amp;url={$url}"><i class="fas fa-sync-alt"/></a>
};

declare %templates:wrap function app:cmif-file-action-disable($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    return
        if ($csharv:cmif-file-index//file[@url=$url]/@disabled)
        then <a style="color: #B72222;" href="?id=enable&amp;url={$url}"><i class="fas fa-times-circle"/></a>
        else <a href="?id=disable&amp;url={$url}"><i class="fas fa-check"/></a>
};

declare %templates:wrap function app:cmif-file-action-delete($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    return
    <a href="?id=deregister&amp;url={$url}"><i class="fas fa-trash"/></a>
};

(: Report on CMIF file :)
declare %templates:wrap function app:cmif-file-report($node as node(), $model as map(*)) {
    let $url := $model("file")/@url/data(.)
    return
    <a href="report.html?url={$url}"><i class="fas fa-file-alt"/></a>
};

declare %templates:wrap function app:get-report($node as node(), $model as map(*), $url as xs:string, $force as xs:string*) as map(*) {
    let $report :=
        if ($force='yes')
        then 
            if (csharv:report($url))
            then collection($config:data-root)//report[file-id=$url]
            else ()
        else if (collection($config:data-root)//report[file-id=$url])
        then collection($config:data-root)//report[file-id=$url]
        else if (csharv:report($url))
        then collection($config:data-root)//report[file-id=$url]
        else ()
    return  
    map { "result" := $report  }
};

declare function app:report-title($node as node(), $model as map(*)) {
    let $report := $model("result")
    let $date := app:format-date($model("result")//@timestamp/data(.), 'all')
    let $stored := $report/file-stored/text()
    let $url := $report/file-id/text()
    let $title := $report/file-title/text()
    let $last-modified := app:format-date($report/file-last-modified/text(), 'all')
    let $last-harvested := app:format-date($report/file-last-harvested/text(), 'all')
    let $editors := 
        for $editor in $model("result")//file-editors/editor
        return
        <a href="mailto:{$editor/email/text()}">{$editor/name/text()}</a>    
    let $correspDesc := $model("result")//feature[@key='correspDesc']/@value/data(.)
    return
   (<h1>Report</h1>,
   <p>{$date}&#160;<a href="?url={$url}&amp;force=yes"><i class="fas fa-sync-alt"/></a></p>,
    <table class="table">
        <tr>
            <td>Stored</td>
            <td>{$stored}</td>
        </tr>
        <tr>
            <td>Title</td>
            <td>{$title}</td>
        </tr>
        <tr>
            <td>Contact</td>
            <td>{$editors}</td>
        </tr>
        <tr>
            <td>URL</td>
            <td><a href="{$url}">{$url}</a></td>
        </tr>
        <tr>
            <td>Last modified</td>
            <td>{$last-modified}</td>
        </tr>
        <tr>
            <td>Last harvested</td>
            <td>{$last-harvested}</td>
        </tr>
        <tr>
            <td>Letters</td>
            <td>{$correspDesc}</td>
        </tr>
    </table>)
};

declare function app:report-validation($node as node(), $model as map(*)) {
    element h2 {'Validation'},
    if ($model("result")//validation/report/status='invalid')
    then local:view-validation-report($node, $model)
    else element p { 'Valid' }
};

declare function app:report-ids($node as node(), $model as map(*)) {
    element h2 {'Entities references'},
    element table {
        attribute class {'table'},
        element tr {
            element th {'Typ'},
            element th {'All'},
            for $authority in $csharv:config//authority
            return 
            element th { $authority/@key/data(.) },
            element th {'Alien'},
            element th {'w/o ID'},
            element th {'%'}
        },
        for $feature-set in $model("result")//feature-set
        return
        element tr {
            element td { $feature-set/@key/data(.) },
            element td { $feature-set/feature[@key='all']/@value/data(.) },
            for $authority in $csharv:config//authority
            return 
            element td { $feature-set/feature[@key=$authority/@key]/@value/data(.) },
            element td { $feature-set/feature[@key='non-supported']/@value/data(.) },
            element td { $feature-set/feature[@key='no-ref']/@value/data(.) },
            element td { $feature-set/feature[@key='no-ref-share']/@value/data(.) }
        }
    }
};

