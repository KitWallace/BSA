module namespace ms = "http://kitwallace.me/ms";

declare namespace ve="http://schemas.openxmlformats.org/markup-compatibility/2006";
declare namespace o="urn:schemas-microsoft-com:office:office";
declare namespace r="http://schemas.openxmlformats.org/officeDocument/2006/relationships";
declare namespace m="http://schemas.openxmlformats.org/officeDocument/2006/math";
declare namespace v="urn:schemas-microsoft-com:vml";
declare namespace wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing";
declare namespace w10="urn:schemas-microsoft-com:office:word";
declare namespace w="http://schemas.openxmlformats.org/wordprocessingml/2006/main";
declare namespace wne="http://schemas.microsoft.com/office/word/2006/wordml";

declare namespace wml = "http://schemas.microsoft.com/office/word/2003/wordml";

import module namespace compression = "http://exist-db.org/xquery/compression";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace httpclient = "http://exist-db.org/xquery/httpclient";

(: load file from the local file system 

declare function ms:get-document($filename) {
  let $file := file:read($filename)
  return $file
};
:)

(:~  
 : simple script to get a zipped file of xml documents from the internet.
 
 :@param uri  the uri of the remote zip file
 :@directory  name of the subdirectory in which to store the files

:)

declare function ms:docx-filter($path as xs:string, $type as xs:string, $param as item()*) as xs:boolean {
 (: pass just the word/document.xml file :)
   $path = "word/document.xml"
};

declare function ms:docx-process($path as xs:string, $type as xs:string, $data as item()? , $param as item()*) {
 (: store the document XML  in the defined collection/filename :)
   xmldb:store($param/@collection, $param/@filename, $data)  
};

declare function ms:get-docx-and-store($uri,$collection , $filename) {
let $zip := httpclient:get(xs:anyURI($uri), true(), ())/httpclient:body/text()
let $filter := util:function(QName("http://kitwallace.me/ms","ms:docx-filter"),3)
let $process := util:function(QName("http://kitwallace.me/ms","ms:docx-process"),4)

let $login :=  xmldb:login("/db","admin","perdika")            
let $store := compression:unzip(
    $zip,
    $filter,
    (),
    $process,
    (<param collection="{$collection}"/>,
     <param filename="{$filename}"/>
    )
   )
return 
  $store
};

declare function ms:merge-texts($doc) {
  <doc>
    {for $p in $doc//w:p
     let $text := string-join($p//w:t," ")
     where $text ne ""
     return
       <p>{$text}</p>
    }
  </doc>
};
declare function ms:merge-wml-texts($doc) {
  <doc>
    {for $p in $doc//wml:p
     let $text := string-join($p//wml:t,"")
     where $text ne ""
     return
       <p>{$text}</p>
    }
  </doc>
};

declare function ms:ml-update-document-xml($doc as element(w:document)) as element(w:document) {
    ms:dispatch($doc)
};

declare function ms:passthru($x as node()) as node()* {
    for $i in $x/node() return ms:dispatch($i)
};

declare function ms:dispatch($x as node()) as node() {
    typeswitch ($x)
        case element(w:p) return ms:mergeruns($x)
        default return element {fn:name($x)} {$x/@*, ms:passthru($x)}
};

declare function ms:mergeruns($p as element(w:p)) as element(w:p) {
    let $pPrvals := if (fn:exists($p/w:pPr)) then $p/w:pPr else ()
    return element w:p{ $pPrvals, ms:map($p/w:r[1]) }

};

declare function ms:descend($r as element(w:r)?, $rToCheck as element(w:rPr)?) as element(w:r)* {
    if (fn:empty($r)) then ()
    else if (fn:deep-equal($r/w:rPr, $rToCheck)) then
        ($r, ms:descend($r/following-sibling::w:r[1], $rToCheck))
    else ()
};

declare function ms:map($r as element(w:r)?) as element(w:r)* {
    if (fn:empty($r)) then ()
    else
        let $rToCheck := $r/w:rPr
        let $matches := ms:descend($r/following-sibling::w:r[1], $rToCheck)
        let $count := fn:count($matches)
        let $this := 
            if ($count) then
                (
                element w:r { $rToCheck,
                element w:t { fn:string-join(($r/w:t, $matches/w:t),"") } }
                )
            else $r
        return  
            (
            $this,
            ms:map(
                if ($count) then 
                    ($r/following-sibling::w:r[position() = (1 + $count)]) 
                else 
                    $r/following-sibling::w:r[1])
            )
};
