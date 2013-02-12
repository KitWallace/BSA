import module namespace anot = "http://kitwallace.me/anot" at "../lib/anot.xqm";
import module namespace bsa = "http://kitwallace.me/bsa" at "../lib/bsa.xqm";

declare option exist:serialize "method=xhtml media-type=text/html";

if (session:get-attribute("user")) 
then
   let $annotations := $bsa:schema/entity[parent=("p","Trip")]   (: should do a transitive closure here :)
   let $trip := request:get-parameter("docid",())
   let $doc := $bsa:trips[id=$trip]  
   return anot:update-annotation($doc,$annotations)
else () 
