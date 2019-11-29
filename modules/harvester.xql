xquery version "3.0";

(:  
    correspSearch Harvester
:)

module namespace csharv="https://correspSearch.net/harvester";

import module namespace cs="http://www.bbaw.de/telota/correspSearch" at "correspSearch.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace httpclient="http://exist-db.org/xquery/httpclient";

declare variable $csharv:config := doc('../config.xml')/csHarvester;
declare variable $csharv:data := '/apps/csHarvester/data/cmif-files';
declare variable $csharv:reports := '/db/apps/csHarvester/data/reports';
declare variable $csharv:cmif-file-index-path := '/db/apps/csHarvester/data/cmif-file-index.xml'; 
declare variable $csharv:cmif-file-index := csharv:load-cmif-file-index();
declare variable $csharv:logs := '/apps/csHarvester/data/logs';
declare variable $csharv:log-file := $csharv:logs||'/log.xml';
declare variable $csharv:log := csharv:load-logfile();
declare variable $csharv:schema := xs:anyURI('../data/schema/cmif.rng');

declare variable $csharv:loglevel := request:get-parameter('loglevel', 'default');
declare variable $csharv:validation := request:get-parameter('validation', 'yes');
declare variable $csharv:force := request:get-parameter('force', 'no');

declare variable $csharv:debug := false();

(: Logging :)

declare function csharv:load-cmif-file-index() {
    if (doc($csharv:cmif-file-index-path)/cmif-files)
    then doc($csharv:cmif-file-index-path)/cmif-files
    else 
       (xmldb:store('/db/apps/csHarvester/data', 'cmif-file-index.xml', <cmif-files></cmif-files>),
        doc($csharv:cmif-file-index-path)/cmif-files)
};

declare function csharv:load-logfile() {
    if (doc($csharv:log-file)/log)
    then doc($csharv:log-file)/log
    else 
       (xmldb:store($csharv:logs, 'log.xml', <log></log>),
        doc($csharv:log-file)/log)
};

declare function csharv:startLog($type) {
    let $attributes :=
        if ($type='update-all')
        then
            map {
                'type' : 'update-all',
                'validation-mode' : $csharv:validation,
                'force-update' : $csharv:force,
                'loglevel' : $csharv:loglevel,
                'urls' : count($csharv:cmif-file-index//file),
                'label' : 'Begin sequence to update all files' 
            }
        else if ($type='update')
        then
            map {
                'type' : 'update',
                'validation-mode' : $csharv:validation,
                'force-update' : $csharv:force,
                'loglevel' : $csharv:loglevel,
                'urls' : '1',
                'label' : 'Begin sequence to update file' 
            }
        else if ($type='register')
        then
            map {
                'type' : 'register',
                'label' : 'Start register sequence' 
            }
        else if ($type='deregister')
        then
            map {
                'type' : 'deregister',
                'label' : 'Start deregister sequence' 
            }  
        else if ($type='report')
        then
            map {
                'type' : 'report',
                'label' : 'Start creating report' 
            }      
        else ()
    return
    csharv:write-log(
    element start {
        for $key in map:keys($attributes)[.!='label']
        return
        attribute { $key } { $attributes($key) },
        $attributes('label')
    })
};

declare function csharv:endLog() {
    let $type := $csharv:log//action[last()]/start/@type
    let $attributes :=
        if ($type='update-all' or $type='update')
        then
            map {
                'urls' : xs:string($csharv:log//action[last()]/start/@urls),
                'duration' : (util:system-dateTime() - xs:dateTime($csharv:log//action[last()]/start/@timestamp)) div xs:dayTimeDuration("PT1S"),
                'errors' : count($csharv:log//action[last()]/error),
                'notModified' : count($csharv:log//action[last()]/status[@type='notModified']),
                'updated' : count($csharv:log//action[last()]/status[@type='stored']),
                'label' : 'End update sequence'
            }
        else if ($type='register')
        then 
            map {
                'urls' : '1',
                'duration' : (util:system-dateTime() - xs:dateTime($csharv:log//action[last()]/start/@timestamp)) div xs:dayTimeDuration("PT1S"),
                'errors' : count($csharv:log//action[last()]/error),
                'notModified' : '-',
                'updated' : count($csharv:log//action[last()]/status[@type='registered']),
                'label' : 'End register sequence'
            }
        else if ($type='deregister')
        then 
            map {
                'urls' : '1',
                'duration' : (util:system-dateTime() - xs:dateTime($csharv:log//action[last()]/start/@timestamp)) div xs:dayTimeDuration("PT1S"),
                'errors' : count($csharv:log//action[last()]/error),
                'notModified' : '-',
                'updated' : '-',
                'label' : 'End deregister sequence'
            }
        else if ($type='report')
        then
            map {
                'type' : 'report',
                'label' : 'End creating report' 
            }             
        else ()
    return
    csharv:write-log(
    element end {
        for $key in map:keys($attributes)[.!='label']
        return
        attribute { $key } { $attributes($key) },
        $attributes('label')
    })
};


declare function csharv:addTimestamp($element as element()) as element() {
    let $name := $element/name()
    let $message := $element/text() 
    let $timestamp := util:system-dateTime()
    return
        element {$name} {
            attribute timestamp { $timestamp },
            for $attribute in $element/@*
            return
            attribute { $attribute/name() } { $attribute/data(.) },
            $element/text() 
        }            
};

declare function csharv:filter-log($element as element()) {
     if ($csharv:loglevel='all' or $csharv:debug)
     then $element
     else if ($csharv:loglevel='default')
     then
        typeswitch($element)
            case element(trace)
                return
                ()
            default 
                return 
                $element
     else (
        $element
     )
};

declare function csharv:write-log($elements as element()*) {
    for $element in $elements
    return
        if (csharv:filter-log($element))
        then (
            if ($element/name()='report')
            then update insert $element into $csharv:log/action[last()]
            else if ($element/name()='start')
            then update insert element action { attribute id { util:uuid() }, csharv:addTimestamp($element) } into $csharv:log
            else update insert csharv:addTimestamp($element) into $csharv:log/action[position()=last()]
        ) else ()
};

declare function csharv:clear-log() {
    for $action in doc($csharv:log-file)//action
    return
        update delete $action
};

declare function csharv:check($elements as element()*) as xs:boolean {
        for $element in $elements
        let $log := csharv:write-log($element)
        return
            typeswitch($element)
            case element(status)
                return
                    if ($element/@type='notModified')
                    then false()
                    else true()
            case element(trace)
                return
                    true()
            case element(error)
                return
                    false()
            default
                return
                    ()
};

(: Tests for registering AND updating :)

declare function csharv:checkIfRegistered($url as xs:string) as xs:boolean {
    let $test :=
        if ($csharv:cmif-file-index//file/@url=$url)
        then <error  type="alreadyRegistered" url="{$url}">URL already registered</error>
        else <trace url="{$url}">URL not yet registered</trace>
    return
    csharv:check($test)
};

declare function csharv:checkURL($url as xs:string) as xs:boolean {
    let $test :=
        if (matches($url, '^http(s?)://'))
        then (
            if (not(matches($url, '\s')))
            then <trace url="{$url}">URL okay</trace>
            else <error  type="whitespaceInURL" url="{$url}">Whitespace in URL</error>
        )
        else <error type="unknownProtocoll" url="{$url}">Unknown Protocoll</error>
    return
    csharv:check($test)
};

declare function csharv:checkStatusCode($url as xs:string) as xs:boolean {
    let $request := httpclient:head($url, true(), ())
    let $test :=
        if ($request/@statusCode='200')
        then <trace url="{$url}">Status code: 200</trace>
        else <error type="wrongStatusCode" url="{$url}">Wrong status code: {$request/@statusCode/data(.)} for {$url}</error>
    return
    csharv:check($test)
};

(: Updating inkl. Tests :)

(:declare function csharv:checkModifiedSince($url as xs:string) as xs:boolean {
    let $last-modification := collection($data)//tei:TEI[.//tei:idno=$url]/tei:publicationStmt//@when
    let $request := httpclient:head($url, true(), <headers><header name="If-Modified-Since" value="Wed, 5 Dec 2018 19:43:31 GMT"></header></headers>)
    let $test :=
        $request
    return
    csharv:check($test)
};:)

declare function csharv:getFile($url) as element() {
    httpclient:get($url, true(), ())
};

declare function csharv:getTEI($url) as element()* {
    let $tei := csharv:getFile($url)//tei:TEI
    let $filename := 'FAILED_'||local:cleanFileName($url)
    let $test :=
        if ($tei)
        then $tei
        else xmldb:store($csharv:logs, $filename, httpclient:get($url, true(), ()))
    return
    $tei
};

declare function csharv:checkWellformed($url) as xs:boolean {
    let $string := serialize(csharv:getTEI($url))
    let $test :=
        if (parse-xml($string))
        then <trace url="{$url}">Wellformed</trace>
        else <error type="notWellformed" url="{$url}">XML document {$url} is not wellformed</error>
    return
    csharv:check($test)
};

declare function csharv:getValidationReport($doc) {
    validation:validate-report($doc, doc($csharv:schema))
};

declare function csharv:checkValidation($url) as xs:boolean {
    let $doc := csharv:getTEI($url)
    let $validation := csharv:getValidationReport($doc)
    let $test :=
        if ($validation//status='valid')
        then <trace url="{$url}">Validated</trace>
        else (<error type="validationFailed" url="{$url}">Validation of {$url} failed</error>, $validation)       
    return
    csharv:check($test)
};

declare function csharv:checkIfModified($url) as xs:boolean {
    let $oldDoc := collection($csharv:data)//tei:TEI[.//tei:idno=$url]
    let $newDoc := csharv:getTEI($url)
    let $test :=
        if ($oldDoc)
        then 
            if ($newDoc//tei:publicationStmt/tei:date/@when > $oldDoc//tei:publicationStmt/tei:date/@when)
            then <trace url="{$url}">Modified</trace>
            else <status type="notModified" url="{$url}">Not modified</status>
        else <trace url="{$url}">New CMIF file {$url}</trace>
    return
    csharv:check($test)
};

declare function local:cleanFileName($url as xs:string) as xs:string {
    let $replace1 := replace($url, 'http://', '')
    let $replace2 := replace($replace1, 'https://', '')
    let $replace3 := replace($replace2, '/', '_')
    return
    $replace3
};

declare function csharv:insert-file-entry($url as xs:string) {
    let $current-user := sm:id()//sm:real/sm:username/text()
    let $update :=
        update insert element file {
            attribute url { $url },
            attribute added-when { current-dateTime() },
            attribute added-by { $current-user }
        } into doc($csharv:cmif-file-index-path)//cmif-files
    let $test :=
        if ($csharv:cmif-file-index//file[@url=$url])
        then <status type="registered">File {$url} registered</status>
        else <error type="notRegistered">File {$url} NOT registered</error>
    return
    csharv:check($test)
};

declare function csharv:store($url) {
    let $doc := csharv:getTEI($url)
    let $filename := local:cleanFileName($url)
    let $test := 
        if (xmldb:store($csharv:data, $filename, $doc))
        then <status type="stored" url="{$url}">Successful stored</status>
        else <error type="notStored" url="{$url}">File {$url} Not stored!</error>
    return
    csharv:check($test)
};

(: Functions to be called :)

(: Später nach oben :)
declare function csharv:getErrorMessage($url) {
    for $error in $csharv:log//action[last()]/error[@url=$url]
    return
    <message type="error">{$error/text()}</message>
};

declare function csharv:register($url as xs:string) {
    (csharv:startLog('register'),
    if (csharv:checkIfRegistered($url))
    then
        if (csharv:checkURL($url))
        then (
            if (csharv:checkStatusCode($url))
            then 
                if (csharv:insert-file-entry($url))
                then (<message type="success">URL succesful registered.</message>)
                else (csharv:getErrorMessage($url))
            else (csharv:getErrorMessage($url))                
        )
        else (csharv:getErrorMessage($url))
     else (csharv:getErrorMessage($url)),   
    csharv:endLog())
};

declare function csharv:register-retrieve($url) {
    let $register := csharv:register($url)
    return
        if ($register/message/type='success')
        then csharv:update($url)
        else $register
};

declare function csharv:get($url as xs:string) {
    if (csharv:checkURL($url))
    then 
        if (csharv:checkStatusCode($url))
        then 
            if (csharv:checkWellformed($url))
            then 
                if (csharv:checkValidation($url) or $csharv:validation='no')
                then
                    if (csharv:checkIfModified($url) or $csharv:force='yes')
                    then 
                        if (csharv:store($url))
                        then ()
                        else csharv:getErrorMessage($url)
                    else (csharv:getErrorMessage($url))
                else (csharv:getErrorMessage($url))
            else (csharv:getErrorMessage($url))
        else (csharv:getErrorMessage($url))
     else (csharv:getErrorMessage($url))  
};

declare function csharv:update($url) {
   (csharv:startLog('update'),
    csharv:write-log(<trace url="{$url}">Begin update for {$url}</trace>), 
    csharv:get($url),
    csharv:endLog(),
    <message type="success">Update for {$url} completed.</message>)
};

declare function csharv:update-all() {
   (csharv:startLog('update-all'),
    for $url at $pos in $csharv:cmif-file-index//file/@url
    let $log := <trace url="{$url}">Begin update all files</trace>
    return
    (csharv:write-log($log), csharv:get($url)),
    csharv:endLog(),
    <message type="success">Update-all sequence completed.</message>)
};

declare function csharv:delete-file($url) {
    let $file := collection($csharv:data)//tei:TEI[.//tei:idno=$url]
    let $filename := substring-after(base-uri($file), 'cmif-files/')
    let $remove :=
        if ($file)
        then xmldb:remove($csharv:data, $filename)
        else ()
    let $test :=
        if (not($file))
        then <error type="failed" url="{$url}">File {$filename} NOT available in DB</error>
        else if (collection($csharv:data)//tei:TEI[./tei:idno=$url])
        then <error type="failed" url="{$url}">File {$filename} NOT removed from DB</error>
        else <status type="deleted" url="{$url}">File deleted in DB </status>
    return
    csharv:check($test)
};

declare function csharv:delete-file-entry($url) {
let $remove-entry :=
    for $file-entry in $csharv:cmif-file-index//file[@url=$url]
    return
        update delete $file-entry
let $test :=
    if ($csharv:cmif-file-index//file[@url=$url])
    then <error type="failed" url="{$url}">Entry in file list NOT removed</error>
    else <trace url="{$url}">Entry in file list removed</trace>
return
csharv:check($test)
};

declare function csharv:deregister($url) {
    (csharv:startLog('deregister'),
    csharv:write-log(<trace url="{$url}">Begin delete file {$url}</trace>), 
    if (csharv:delete-file($url))
    then 
        if (csharv:delete-file-entry($url))
        then <message type="success">URL: {$url} deleted</message> 
        else csharv:getErrorMessage($url)
    else csharv:getErrorMessage($url), 
    csharv:endLog())
};

declare function csharv:report($url) {
    let $start := csharv:startLog('report')
    let $log := csharv:write-log(<trace url="{$url}">Create report for file {$url}</trace>) 
    let $report := csharv:createReport($url)
    let $store := csharv:storeReport($report)
    let $end := csharv:endLog()
    return
    if ($store)
    then <message type="success">Report for {$url} created</message>
    else csharv:getErrorMessage($url)
};

declare function csharv:storeReport($report as element()) {
    let $filename := local:cleanFileName($report/file-id/text())
    let $url := $report//file-id/text()
    let $test := 
        if (xmldb:store($csharv:reports, $filename, $report))
        then <status type="storedReport" url="{$url}">Report successfully stored</status>
        else <error type="notStoredReport" url="{$url}">Report for {$url} not stored!</error>
    return
    csharv:check($test)
};

declare function local:report-ids($file as node(), $element-name as xs:string) as element() {
    let $all :=
       (<feature key="all" value="{count($file//tei:correspAction/*[name()=$element-name])}" />,
        <feature key="no-ref" value="{count($file//tei:correspAction/*[name()=$element-name and not(@ref)])}" />,
        <feature key="no-ref-share" value="{
            if (count($file//tei:correspAction/*[name()=$element-name])!=0)
            then round((count($file//tei:correspAction/*[name()=$element-name and not(@ref)]) div count($file//tei:correspAction/*[name()=$element-name])) * 100)
            else ('-')}" />)
    let $authority-files :=
        for $authority in $csharv:config//authority
        let $key := $authority/@key
        let $base-url := $authority/@base-url
        let $count := count($file//*[name()=$element-name and matches(./@ref, $base-url)])
        return
         <feature key="{$authority/@key/data(.)}" value="{$count}" />
    let $supported-authorities :=
        string-join(
            for $authority at $pos in $csharv:config//authority
            return
                if ($pos=1)
                then $authority/@base-url
                else '|'||$authority/@base-url)
    let $non-supported-ids :=        
        <feature key="non-supported" value="{count($file//*[name()=$element-name and @ref and not(matches(@ref, $supported-authorities))])}"/>
    return
    <feature-set key="{$element-name}">
        {$all,
         $authority-files,
         $non-supported-ids}
    </feature-set>
};

declare function csharv:createReport($url) {
    let $file := csharv:getTEI($url)
    let $statistics :=
           (<feature key="correspDesc" value="{count($file//tei:correspDesc)}"/>,
            local:report-ids($file, 'persName'), 
            local:report-ids($file, 'orgName'),
            local:report-ids($file, 'placeName'))
    let $validation-report := csharv:getValidationReport($file)
    let $editors := 
        for $editor in $file//tei:titleStmt//tei:editor
        return
        <editor>
            <name>{$editor/text()}</name>
            <email>{$editor/tei:email/text()}</email>
        </editor>
    return
    <report timestamp="{current-dateTime()}" id="{util:uuid()}">
        <file-id>{$url}</file-id>
        <file-title>{$file//tei:titleStmt/tei:title/text()}</file-title>
        <file-editors>{$editors}</file-editors>
        <file-last-modified>{$file//tei:publicationStmt/tei:date/@when/data(.)}</file-last-modified>
        <file-stored>{if (collection($csharv:data)//tei:TEI[.//tei:idno=$url]) then 'yes' else 'no'}</file-stored>
        <validation>
            {$validation-report}
        </validation>
        <statistics>
           {$statistics}
        </statistics>
    </report>
};

declare function csharv:clear-reports() {
    (: Kürzere Schreibweise der Funtion ergibt Server error :)
    let $filenames := 
        for $file in collection($csharv:reports)//report
        return
        substring-after(base-uri($file), 'reports/')
    let $delete :=        
        for $filename in $filenames 
        return
        xmldb:remove($csharv:reports, $filename)
    return
    ()
};