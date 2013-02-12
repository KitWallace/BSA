import module namespace bsa = "http://kitwallace.me/bsa" at "../lib/bsa.xqm";

declare option exist:serialize "method=xhtml media-type=text/html";

let $name := normalize-space(request:get-parameter("name",()))
let $trip := request:get-parameter("trip",())
let $match := bsa:find-location($name, $trip)
return
  $match
