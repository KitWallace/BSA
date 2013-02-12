module namespace bsa = "http://kitwallace.me/bsa";
import module namespace kwic ="http://exist-db.org/xquery/kwic";
import module namespace metar ="http://kitwallace.me/metar" at "/db/apps/metar/metar.xqm";
import module namespace date="http://kitwallace.me/date" at "/db/lib/date.xqm";
import module namespace ui= "http://kitwallace.me/ui" at "/db/lib/ui.xqm";
import module namespace wfn= "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ms= "http://kitwallace.me/ms" at "/db/lib/ms.xqm";
import module namespace log ="http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace anot ="http://kitwallace.me/anot" at "../lib/anot.xqm";

declare namespace kml = "http://www.opengis.net/kml/2.2";
declare variable $bsa:db := "/db/apps/BSA/";
declare variable $bsa:secret :="*******";
declare variable $bsa:config := doc(concat($bsa:db,"system/config.xml"))/app-info;
declare variable $bsa:schema := doc(concat($bsa:db,"system/schema.xml"))/schema;
declare variable $bsa:web-page := $bsa:config/web-page;
declare variable $bsa:data := collection(concat($bsa:db,"data"));
declare variable $bsa:trips := collection(concat($bsa:db,"trips"))//Trip;
declare variable $bsa:routes := doc(concat($bsa:db,"data/routes.xml"))/Routes;
declare variable $bsa:users := doc($bsa:config/users)//user;
declare variable $bsa:userfile := doc($bsa:config/users)/users;
declare variable $bsa:photoindex := doc(concat($bsa:db,"data/photos.xml"))/photos;
declare variable $bsa:forecasts := concat($bsa:db,"forecasts/");
declare variable $bsa:months := tokenize(
   "Jan Feb Mar April May June July Aug Sep Oct Nov Dec"," ");
   
(:  ----------------------- Basic functions ---------------------------- :)
declare function bsa:get-entity($entity) {
element {$entity/@name}
  {for $attribute in $entity/attribute
   return
     ui:get-parameter($attribute/@name/string(), $attribute/@default/string())
  }
};

declare function bsa:format-date($date) {
  if (exists($date) and $date castable as xs:date)
  then 
     datetime:format-date($date,"dd MMM yy")
  else "undated"
};

(: ----------------- login --------------------------- :)

declare function bsa:login-form() {
 <div>
   <form action="?" method="post">
     email address<input name="email" size="30"/>
     <input type="password" name="password"/>
     <input type="submit" name="mode" value="login"/>
   </form>
 </div>
};

declare function bsa:login() {
  let $email := request:get-parameter("email",())
  let $password := request:get-parameter("password",())
  let $user := $bsa:users[email=$email]
  return
    if (exists($user) and util:hash($password,"MD5") = $user/password)
    then 
       let $session := session:set-attribute("user",$user/username)
       return request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=home")))
    else 
       bsa:login-form()
};

declare function bsa:logout() {
  let $invalidate := session:invalidate()
  return
     request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=home")))
};

(: ----------------- user registration ---------------------- :)

declare function bsa:register-form() {
 <div>
      <form action="?" method="post">
        Email address <input name="email" size="30"/>
        Username <input name="username" size="30"/>
        Password <input type="password" name="password"/>
        Repeat Password <input type="password" name="password2"/>       
        Secret <input type="text" name="secret"/>       
        <input type="submit" name="mode" value="register"/>
     </form>
  </div>
};

declare function bsa:register () {
let $email := request:get-parameter("email",())
let $username := request:get-parameter("username",())
let $password := request:get-parameter("password",())
let $password2 := request:get-parameter("password2",())
let $secret := request:get-parameter("secret",())
let $existing-member := $bsa:users[username=$username]
return
if (empty($existing-member) and $username ne "" and  $password ne "" and $password = $password2  and contains ($email,"@") and $secret = $bsa:secret)
then  
   let $login := bsa:create-member($email,$username,$password)
   return response:redirect-to(xs:anyURI(concat(request:get-uri(),"?mode=login-form")))
   
else 
  response:redirect-to(xs:anyURI(concat(request:get-uri(),"?mode=home")))
};

declare function bsa:create-member($email, $username, $password) {
  let $user := 
<user>
   <username>{string($username)}</username>
   <email>{string($email)}</email>
   <password>{util:hash($password,"MD5")}</password>
   <date-joined>{current-date()}</date-joined>
</user>
  let $update := if (exists($bsa:users[username=$username]))
                 then <error>membername already exists</error>
                 else update insert $user into $bsa:userfile
  return $update
};

(: ------------------------ Weather ------------------------- :)
(:
  retrieve the METAR data for the nearest station at the nearest time
:)

declare function bsa:weather($wp as element(wp)) as element(report)?{
if (exists($wp/@lat))
then
let $icao :=   metar:find-station(xs:decimal($wp/@lat),xs:decimal($wp/@long),1.0)
return
  if ($icao)
  then 
      let $reports := metar:get-metar($icao, $wp/@date)
      let $report := metar:report-at-time($reports, ($wp/@time,"12:00")[1])
      return $report
  else ()
else ()
};

(: ------------------------ Newsletter ------------------------------- :)
declare function bsa:newsletter($id) {
 let $doc := doc(concat($bsa:db,"newsletters/",$id,if (ends-with($id,".xml")) then "" else ".xml"))/*
 return 
    ms:merge-wml-texts($doc)
};

declare function bsa:list-newsletters($query as element(query)) {
   <div class="page">
      <div id="leftside">
       <h2> Newsletters</h2>
       {if ($query/user)
       then
       <form enctype="multipart/form-data" method="post" action="?">
         <input type="hidden" name="mode" value="upload"/>
         <input type="hidden" name="type" value="Newsletter"/>
         <fieldset>
        <legend>Upload newsletter:</legend>
        <input type="file" name="file" size="50"/>  <br/>

        <label for="source">Source</label>
        <input type="text" name="source" value="BSA"/>
        <label for="year">Year</label>
        <select name="year">
           {for $year in reverse(2000 to 2012)
           return <option>{$year}</option>
           }
        </select>      
        <label for="month">Month</label>
        <select name="month">
           {for $month in $bsa:months
           return <option>{$month}</option>
           }
        </select>      
        <input type="submit" value="Upload"/>
    </fieldset>
      </form>
       else ()
       }
       <table class="sortable">
       <tr><th>Newsletter</th><th># trips</th></tr>
      {          
       let $index := doc(concat($bsa:db,"data/newsletters.xml"))/Newsletters 
       for $newsletter in $index/Newsletter
       let $count := count($bsa:trips[newsletter = $newsletter/id])
       
       order by $newsletter/yymmdd descending
       return
       <tr>
          <td>
            {if ($count)
            then <a href="?type=Newsletter&amp;id={$newsletter/id}&amp;mode=view">{$newsletter/id/string()}</a>
            else $newsletter/id/string()
             }
          </td>
          <td>{$count}</td>
          {if ($query/user)
          then <td><a href="?type=Newsletter&amp;id={$newsletter/id}&amp;mode=extract">Extract trips</a></td>
          else ()
          }
       </tr>
      }
     </table>
    </div>
    {bsa:photo-selection(4)}
   </div>
};

declare function bsa:view-newsletter($query as element(query)) as element(div) {
<div class="page">
  <div id="leftside">
  <h2>Newsletter {$query/id/string()}</h2>
          {if (exists($query/user))
          then <a href="?mode=extract&amp;type=Newsletter&amp;id={$query/id}">Extract</a>
          else ()
          }
          <table class="sortable">
           <tr><th>Yacht</th><th>Started</th></tr>
           {for $trip in $bsa:trips//Trip[newsletter=$query/id]
           let $startDate := bsa:trip-startDate($trip)
           return
              <tr>
                 <td>{bsa:trip-vessel($trip)}</td>
                 <td><a  sorttable_customkey="{$startDate}" href="?mode=view&amp;type=Trip&amp;id={$trip/id}">{bsa:format-date($startDate)}</a></td>
               </tr>
           }
          </table>
       </div>
    {bsa:photo-selection(1)}
 </div>
};

declare function bsa:upload-newsletter($query as element(query)) {
   <div class="page">
       <h2>Newsletter</h2>
       {
         let $index := doc(concat($bsa:db,"data/newsletters.xml"))/Newsletters 
         let $source := request:get-parameter("source",())
         let $month := request:get-parameter("month",())
         let $year := request:get-parameter("year",())
         let $id := concat($source,$month,substring($year,3))
         let $login := xmldb:login($bsa:db,"admin","perdika")
         let $store := xmldb:store(concat($bsa:db,"newsletters"), concat($id,".xml"), request:get-uploaded-file-data('file'))
         let $monthindex := index-of($bsa:months,$month)
         let $yymmdd :=  concat($year,"-",date:zero-pad($monthindex),"-01")
         let $new-entry :=
          <Newsletter>
            <id>{$id}</id>
            <yymmdd>{$yymmdd}</yymmdd>
         </Newsletter>
        let $old-entry := $index/Newsletter[id=$id]
        let $update := 
           if (exists($old-entry))
           then update replace $old-entry with $new-entry
           else update insert $new-entry into $index
        return
          response:redirect-to(xs:anyURI(concat(request:get-uri(),"?mode=extract&amp;type=Newsletter&amp;id=",$id)))
       }   
   </div>
};

(:  ----------------- Location /Waypoint ----------------------------   :)
(:
 in the reports, wps can be expressed in relative form, for example if the location is omitted, it defaults to the immediately 
 previous location. Dates may be expressed as day numbers relative to the start date of the trip.  This function expands this 
 abbreviated format to yield an absolute form containing date, time and position(lat,long)
 
:)
declare function bsa:full-wp($wp as element(wp)) as element(wp) {
  let $name :=  $wp/@name
  let $lat := $wp/@lat
  let $long := $wp/@long
  let $trip :=  $wp/ancestor::Trip
  let $startDate := bsa:trip-startDate($trip)
  return 
    let $date :=
       let $last := ($wp/@day,$wp/@date,$wp/preceding::wp[(@date,@day)][1]/(@date,@day))[1]
       return
         if (exists($last) and exists($startDate) and $startDate ne "") 
         then  
             if ($last castable as xs:integer)  (: a day offset :)
             then xs:date($startDate) + xdt:dayTimeDuration(concat("P" , xs:integer($last) - 1, "D"))
             else $last
         else $startDate                  
   let $time := 
       if (exists($wp/@time) and $wp/@time ne "")
       then $wp/@time
       else ()               
   return
      element wp {
        $wp/@name,
        $wp/@lat,
        $wp/@long,
        attribute date {$date},
        if (exists($time)) then attribute time {$time} else () 
      }           
};

declare function bsa:wp-to-info($wp, $i) {
       <div id="wp{$i}">
          <div>
           {if (exists($wp/@name))
            then <a href="?mode=view&amp;type=Location&amp;id={$wp/@name}">{$wp/@name/string()}</a>
            else ()
            } 
           &#160;{concat($wp/@lat,",",$wp/@long)}
          </div>       
          {if (exists ($wp/@date) and $wp/@date ne "")
          then
              let $wikidate := date:wikidate($wp/@date)
              let $url := concat("http://en.wikipedia.org/wiki/Portal:Current_events/",$wikidate)
              return 
                <div>
                     {bsa:format-date($wp/@date)}&#160; {$wp/@time/string()}
                      <a class="external" href="{$url}">Wikipedia News</a>
                </div>
           else ()
           }
            {if ($wp/weather)
             then 
               let $weather := $wp/weather
               let $summary := concat(if (exists($weather/wind-speed)) then concat($weather/wind-speed," kts from ") else " ",$weather/wind-direction-points," ",$weather/temp, "C, ",$weather/pressure,"mb ", $weather/conditions)
               return
                 <div>
                   Weather at <a class="external" href="{metar:history-page($weather/icao,$wp/@date)}">
                    {$weather/icao/string()}</a> &#160;
                    {$summary}
                 </div> 
             else ()
            }
       </div>
};

declare function bsa:location-to-wp($location as element(Location)) as element(wp) {
       element wp {
           attribute name {$location/name[1]},
           attribute lat {$location/lat},
           attribute long {$location/long}
       }
};

(: search for matching wps, giving preference to matches in the current trip 
:)
declare function bsa:find-location($name as xs:string,$trip as xs:string) as element(wp)* {
  let $location := $bsa:data//Location[name=$name][1]
  return
    if (exists($location))
    then  bsa:location-to-wp($location)
     else
     let $trip-wp := bsa:trip($trip)//wp[@name = $name]
     return 
         if (exists($trip-wp))
         then $trip-wp[1]
         else 
            ($bsa:trips//wp[@name = $name])[1]
};

declare function bsa:list-locations($query as element(query))  as element(div){
  <div class="page">
   <div id="heading">
    <h3>List of locations</h3>
    </div>
    <div id="info">
    {let $wps := $bsa:trips//wp
     for $wp at $i in 
        for $name in distinct-values($wps/@name) 
        let $wp := $wps[@name=$name][1]
        order by $wp/@name
        return $wp
     let $data := wfn:items-to-json(($wp/@lat,$wp/@long))
     return
       <span class="wp {$data}">
          <a href="?mode=view&amp;type=Location&amp;id={encode-for-uri($wp/@name)}">{$wp/@name/string()}</a>
          <span class="mapdata" id="wp{$i}">
            <a href="?mode=view&amp;type=Location&amp;id={encode-for-uri($wp/@name)}">{$wp/@name/string()}</a>
          </span>
          <img src="images/lightblue{$i}.png" alt="map"/>        
       </span>
     }
    </div>
    <div id="map_canvas" style="top:200px" />    
 </div>
};

declare function bsa:view-location($query as element(query)) as element(div) {
let $name := $query/id
let $wps := $bsa:trips//wp[@name=$name]
let $wp := $wps[1]
let $location := $bsa:data//Location[name=$name]
let $lat := ($location/lat,$wp/@lat)[1]
let $long := ($location/long,$wp/@long)[1]
let $data := wfn:items-to-json(($lat,$long))
return 
<div class="page">
 <div id="heading">
    <h2>{$name}</h2>
 </div>
 <div id="info">
       {if (count($location/name) > 1 )
        then <p>Also known as <em>{string-join($location/name[position() > 1],", ")}</em>.</p>
        else ()
       }
       {util:parse(concat("<p>",$location/description,"</p>"))}
        <p>{string($lat)},{string($long)}</p>
        {if (exists($lat))
        then
          <div class="wp {$data}">
            <div class="mapdata" id="wp1">
               <h2>{$name} Lat/long: {string($lat)},{string($long)}</h2>
            </div>
          </div>
        else ()
       }
       <ul>
         <li><a class="external" href="http://maps.google.com/maps?q={$lat},{$long} ({$name})&amp;z={if ($location/type="Area")then "11" else "16"}">Google Map </a></li>
         {if ($location/webpage)
         then 
           <li><a  class="external" href="{$location/webpage}">Web page</a></li>
          else ()
          }
           <li><a  class="external" href="http://en.wikipedia.org/wiki/{replace($name[1]," ","_")}">Wikipedia</a></li>
           <li><a  class="external" href="http://www.panoramio.com/map/#lt={$lat}&amp;ln={$long}&amp;z=2">Panoramio</a></li>
        </ul> 
       {bsa:list-selected-trips( $bsa:trips[.//wp/@name = $name] )}
   </div>
   <div id="map_canvas"  style="top:200px;"/>
</div>
};

(: ------------------ Route - cached computed data ------------------- :)

(: extends the trip report with contextual data. 
:)
declare function bsa:get-route($query as element(query)) as element(Route) {
  let $trip := bsa:trip($query/id)
  let $report := $trip/report
  return
<Route>
     {$query/id}
     {
     for $wp at $i in $report//wp
     let $fwp:=  bsa:full-wp($wp)
     let $weather := if (exists($fwp/@date) and $fwp/@date ne "") then bsa:weather($fwp) else ()
     return
       <wp>
           {$fwp/@*}
           {if (exists($weather)) then <weather>{$weather/*}</weather> else ()}
       </wp>
     }
</Route>
};

(: accesses the extended Route data.  Because it takes time to acquire the context data, especially the
   METAR data , the Route data is cached.  The data can be refreshed if the refresh parameter is set in the url
:)
declare function bsa:route($query as element(query)) as element(Route){
  let $cachedroute := $bsa:routes/Route[id=$query/id]
  let $update := 
      if (exists($query/refresh) or empty($cachedroute))
      then 
         let $route := bsa:get-route($query)
         return
            if (exists($cachedroute))
            then update replace $cachedroute with $route
            else update insert $route into $bsa:routes
      else  ()
(:  let $e := error((),"r", $bsa:routes/Route[id=$query/id]) :)
  return 
    $bsa:routes/Route[id=$query/id]
};

(: ------------------- Trip ------------------------------------------ :)

declare function bsa:trip($id as xs:string) as element(Trip)? {
   $bsa:trips[id=$id]
};

declare function bsa:trip-label( $trip as element(Trip)) {
 <span>Trip on { bsa:trip-vessel($trip)} starting {bsa:format-date(bsa:trip-startDate($trip))} in 
   <a href="?mode=view&amp;type=Newsletter&amp;id={$trip/newsletter}">{$trip/newsletter/string()}</a>
 </span>
};



declare function bsa:next-trip-id() {
  let $next := xs:integer($bsa:config/trip-id) + 1
  let $update := update replace $bsa:config/trip-id with element trip-id {$next}
  return concat("trip-",$next)
};

declare function bsa:trip-vessel($trip as element(Trip)) {
  let $vessel := ($trip//vessel)[1]
  return
         if (exists($vessel/@name))
         then <em>{$vessel/@name/string()}</em>
         else if (exists($vessel/@type))
         then concat(if (lower-case(substring($vessel/@type,1,1)) = ("a","e","i","o","u","h")) then ' an ' else ' a ',$vessel/@type)
         else " a yacht "
};

declare function bsa:trip-skipper($trip as element(Trip)) {
  let $skipper := $trip//skipper[1]
  return
    if (exists($skipper))
    then $skipper/@name/string()
    else ""
};

declare function bsa:trip-startDate($trip as element(Trip)) {
  let $startDate := $trip//startDate[1]
  return
    if (exists($startDate))
    then $startDate/@date/string()
    else ""
};

declare function bsa:trip-location($trip as element(Trip)) {
  let $location := ($trip//wp)[1]
  return
    if (exists($location))
    then $location/@name/string()
    else ""
};

declare function bsa:trip-wps($trip as element(Trip)) {
  count($trip//wp)
};


declare function bsa:trip-words($trip as element(Trip)) {
   distinct-values(($trip//skipper/@name,$trip//crew/@name,$trip//wp/@name,$trip//vessel/@name))
};

declare function bsa:list-trips($query as element(query)) as element(div) {
<div class="page">
   <div id="leftside">
     {bsa:list-selected-trips($bsa:trips)}
    </div>
    {bsa:photo-selection(4)}
</div>
};

(:
 creates the main Trip page, including the report and the route map
:)

declare function bsa:map-info($query as element(query)) as element(div)  {
  <div class="mapdata">
     {let $route := bsa:route($query)
      for $wp at $i in $route/wp
      return
         bsa:wp-to-info($wp, $i)
     }
  </div>
};

declare function bsa:view-trip($query as element(query)) as element(div) {
let $trip := bsa:trip($query/id)
let $route := bsa:route($query)
let $report := bsa:render($trip/report,$trip, $route)
return
<div class="page">
  <h3>{bsa:trip-label($trip)}</h3>
  <div id="info" class="route">
     {$report}
  </div>
  <div id="map_canvas"/>
  {bsa:map-info($query)}
</div>
};

declare function bsa:list-selected-trips($trips) as element(div)?{
  if (empty($trips)) then ()
  else
    <div>
     <h3>Trips</h3>
     <table class="sortable" id="selected-trips">
     <tr>
       <th width="20%">Date (# wps)</th>
       <th>Boat</th>
       <th>Skipper</th>
       <th>Location</th>
      </tr>
     { for $trip in $trips
       let $skipper := bsa:trip-skipper($trip)
       let $vessel := bsa:trip-vessel($trip)
       let $startDate := bsa:trip-startDate($trip)
       let $location := bsa:trip-location($trip)
       let $nwps := bsa:trip-wps($trip)
       order by $startDate descending
       return
       <tr>
         <td sorttable_customkey="{$startDate}"><a  href="?mode=view&amp;type=Trip&amp;id={$trip/id}">{bsa:format-date($startDate)}</a>({$nwps})</td>
         <td><a href="?mode=view&amp;id={$trip//vessel[1]/@name}&amp;type=Vessel">{bsa:trip-vessel($trip) }</a> </td>
         <td><a href="?mode=view&amp;type=Person&amp;id={$skipper}">{$skipper}</a></td>
         <td><a href="?mode=view&amp;type=Location&amp;id={$location}">{$location}</a></td>
        </tr>
      }
     </table>
    </div>
};

(:
  renders a trip report, working recursively top-down using typeswitch to render each element type
:)
declare function bsa:render($items as node()* , $trip, $route) {
for $item in $items
return 
   typeswitch ($item)
      case element(wp)
             return 
                let $index := wfn:index-of($trip//wp,$item)
                let $wp := $route//wp[$index]
                let $data := wfn:items-to-json($wp/@*)
                return            
            <span class="wp note {$data}" title="{$item/@name}" >
              <span>{bsa:render($item/node(),$trip, $route)}</span>
              <img src="images/lightblue{$index}.png" alt="Map"/>
            </span>
      case element(forecast)
          return
             <a href="{concat($bsa:web-page,"forecasts/",$item/@file,"_Shipping_Forecast_UK.txt")}">
                {bsa:render($item/node(), $trip, $route)}
             </a>
      case element(vessel)
          return 
             <a href="?mode=view&amp;type=Vessel&amp;id={$item/@name}">
                {bsa:render($item/node(), $trip, $route)}
             </a>
      case element(skipper)
          return 
             <a href="?mode=view&amp;type=Person&amp;id={$item/@name}">
                {bsa:render($item/node(), $trip, $route)}
             </a>
       case element(crew)
          return 
             <a href="?mode=view&amp;type=Person&amp;id={$item/@name}">
                {bsa:render($item/node(), $trip, $route)}
             </a>
      case element(startDate)
          return 
             <span class="date" title="{$item/@date}">
                {bsa:render($item/node(), $trip, $route)}
             </span>
      case element(organisation)
          return 
             <a href="?mode=view&amp;type=Organisation&amp;id={$item/@name}">
                {bsa:render($item/node(), $trip, $route)}
             </a>
      case element(link)
          return 
             <span class="link" title="{$item/@name}">
                <a class="external" href="{$item/@url}">
                  {bsa:render($item/node(), $trip, $route)}
                </a>
             </span>
      case element()
          return 
              element {name($item)} {bsa:render($item/node(),$trip,$route)}
      default return $item
};

(:  functions for the editor :)

declare function bsa:try-delete-trip($query) {
 let $id := $query/id
 let $trip := bsa:trip($id)
 return
    if (exists($trip))
    then 
      <div> You are about to delete trip {$id} - {bsa:trip-label($trip)}  - <a href="?mode=delete&amp;type=Trip&amp;id={$id}">Really Delete?</a> 
      </div>
   else 
      <div>No trip to delete</div>
 };
 
declare function bsa:delete-trip($query) {
 let $id := $query/id
 let $trip := bsa:trip($id)
 let $trip-file := util:document-name($trip)
 let $login := xmldb:login($bsa:db,"admin","perdika")
 return
    if (exists($trip))
    then 
      xmldb:remove(concat($bsa:db,"trips"),util:document-name($trip))
   else 
     ()
 };
 
declare function bsa:create-trip($query) {
let $id := $query/id
let $newsletter := bsa:newsletter($id) 
let $trips := $bsa:trips[newsletter=$id]
let $tripParas := for $trip in $trips return $trip/(firstPara to lastPara)
return 
<div>
  <h2>Newsletter {$id}</h2>
  <form action="?">
   <input type="hidden" name="mode" value="store"/>
   <input type="hidden" name="type" value="Trip"/>
   <input type="hidden" name="newsletter" value="{$id}"/>
   <label for="firstPara">First Paragraph</label><input type="text" name="firstPara" id="firstPara"/>
    <label for="lastPara">Last Paragraph</label><input type="text" name="lastPara" id="lastPara"/>
   <button type="button" onclick="selectText()">Select Text</button>
   <input type="submit" value="Create Trip"/>
   <hr/>
   <div id="paragraphs">
   {for $p  at $i in $newsletter/*:p
    return
      <p id="{$i}" title="Para {$i}">
        {if ($i = $tripParas) then attribute style {"background-color:lightgray"} else ()}
        {$p/node()}
      </p> 
   }
   </div>
  </form>
 </div>
};

declare function bsa:store-trip($query){
 let $trip-entity := $bsa:schema/entity[@name="Trip"]
 let $trip := bsa:get-entity($trip-entity)
 let $newsletter := bsa:newsletter($trip/newsletter)
 let $firstPara := xs:integer($trip/firstPara)
 let $lastPara := xs:integer($trip/lastPara)
 let $paras := $newsletter/p[position() ge $firstPara] [position() le ($lastPara - $firstPara + 1)]
 let $dblogin := xmldb:login($bsa:db,"admin","perdika")
 let $tripid := bsa:next-trip-id()
 let $route := $bsa:routes[id=$tripid]
 let $removeCache := if ($route) then update delete $route else ()
 let $newtrip := 
          <Trip>
           <id>{$tripid}</id>
           {$trip/*}
           <report>
             {$paras}
          </report>
         </Trip>
  let $valid :=  $lastPara > $firstPara
  
  let $store := 
             if ($valid)
             then xmldb:store(concat($bsa:db,"trips"),concat($tripid,".xml"),$newtrip)
             else ()
  return
             <div>          
              {if ($valid)
               then response:redirect-to(xs:anyURI(concat(request:get-uri(),"?mode=edit&amp;type=Trip&amp;id=",$tripid)))
               else <div> First Paragraph {$firstPara} after Lats Paragraph {$lastPara}. Go back to the previous page to correct.</div>
              }
            </div>
};

(: -------------------------- Person ---------------------- :)
declare function bsa:list-persons($query as element(query)) as element(div){

let $skippers := $bsa:data//Organisation[1]/Member[role="Club Skipper"]/name/string()
let $sailors := distinct-values($bsa:trips//(crew|skipper)/@name )
return
<div class="page">
    <div id="leftside">
     <h2>Club Skippers</h2>
     <div class="list">
      { wfn:node-join(
        for $person in $skippers
        order by $person
        return   
           <a href="?mode=view&amp;type=Person&amp;id={$person}">{$person}</a> 
        ,", "
        )
      }
     </div>
     <h2>Sailors</h2>
     <div class="list">
      { wfn:node-join(
        for $person in $sailors
        where not ($person = $skippers)
        order by $person
        return
         <a href="?mode=view&amp;type=Person&amp;id={$person}">{$person}</a> 
        ,", "
        )
      }
     </div>
    </div>
    {bsa:photo-selection(1)}
</div> 
};

declare function bsa:view-person($query as element(query)) as element(div) {
let $name := $query/id/string()
return
<div class="page">
 <div id="leftside">
 <h2>{$name}</h2>
 {let $person := $bsa:data//Person[name=$name]
   return 
      if (exists($person))
      then 
         <table class="sortable">
          {for $data in $person/(* except name)
           return
             <tr>
                <th>{name($data)}</th>
                <td>{$data/string()}</td>
             </tr>
          }
         </table>
      else ()
   }
 {if (exists($bsa:data//Organisation[Member/name = $name]))
 then 
 (<h3>Organisations</h3>,
 <table class="sortable">
   <tr><th>Name</th><th>Role</th></tr>
   {for $member in $bsa:data//Organisation/Member[name = $name]
    let $organisation := $member/parent::Organisation
    return
      <tr>
         <td><a href="?mode=view&amp;type=Organisation&amp;id={$organisation/name}">{$organisation/name/string()}</a></td>
         <th>{$member/role/string()}</th>
      </tr>
   }
 </table>
 )
 else ()
 }
 {bsa:list-selected-trips($bsa:trips[.//(skipper|crew)/@name=$query/id])}
    </div>
    {bsa:photo-selection(1)}

</div>
};

(: ------------------------- Vessel -------------------------- :)
declare function bsa:list-vessels($query as element(query)) as element(div) {
<div class="page">
   <div id="leftside">
     <h2>Yachts</h2>
     <table class="sortable">
      <tr class="header">
      <th>Name</th>
      <th>Type</th>
      <th>Number of trips</th>
      </tr>
      {for $vessel-name in distinct-values($bsa:trips//vessel/@name)
       let $vessel-data := $bsa:trips//vessel[@name=$vessel-name]
       order by $vessel-name
       return
       <tr>
          <td><a href="?mode=view&amp;type=Vessel&amp;id={$vessel-name}">{$vessel-name}</a> </td>
          <td>{string(($vessel-data/@type)[1])}</td>
          <td>{count($bsa:trips[.//vessel/@name=$vessel-name])}</td> 
       </tr>
      }
     </table>
    </div>
   {bsa:photo-selection(3)}
</div> 
};

declare function bsa:view-vessel($query as element(query)) as element(div) {
let $vessel-data := $bsa:trips//vessel[@name = $query/id]
let $type := ($vessel-data/@type)[1]
let $charter := ($vessel-data/@charteredFrom)[1]
return
<div class="page">
  <div id="leftside">
   <h2>{$query/id/string()}</h2>
   {
       (if ($type) then <div>Type: {$type/string()}</div> else (),
        if ($charter) then <div>Charter: <a href="?mode=view&amp;type=Organisation&amp;id={$charter}">{$charter/string()}</a></div> else ()
       )
   }
   {bsa:list-selected-trips($bsa:trips[.//vessel/@name = $query/id])}
  </div>
 {bsa:photo-selection(1,($vessel-data/@name)[1])}
</div>
};

(: ---------------------- Organisations ----------------------- :)
declare function bsa:list-organisations($query as element(query)) as element(div) {
<div class="page">
   <div id="leftside">
     <h2>Organisations</h2>
     <table class="sortable">
      {for $organisation in distinct-values(($bsa:data//Organisation/name,$bsa:trips//organisation/@name))
       return
       <tr>
          <td><a href="?mode=view&amp;type=Organisation&amp;id={$organisation}">{string($organisation)}</a> </td>
       </tr>
      }
     </table>
     </div>
    {bsa:photo-selection(1)}
</div> 
};

declare function bsa:view-organisation($query as element(query)) as element(div) {
<div class="page">
   <div id="leftside">
   <h2>{$query/id/string()}</h2>
 {let $organisation := $bsa:data//Organisation[name=$query/id]
  return 
     ( if (exists($organisation))
       then 
         <table>
          <tr> 
            <th>Location</th>
            <td><a href="?mode=view&amp;type=Location&amp;id={$organisation/location}">{$organisation/location/string()}</a></td>
          </tr>
          {if (exists($organisation/link))
          then
           <tr> 
            <table>
            {for $link in $organisation/link
            return 
               <tr><td><a href="{$link/@href}">{$link/@title/string()}</a></td></tr>
            }
            </table>
          </tr> 
          else ()
          }
         </table>
      else () ,
      if (exists($organisation/Member))
      then
      (<h3>Members</h3>,
       <table class="sortable">
         <tr class="header"><th>Name</th><th>Role</th></tr>
         {for $member in $organisation/Member
          return
           <tr>
             <td><a href="?mode=view&amp;type=Person&amp;id={$member/name}">{$member/name/string()}</a></td>
             <td>{$member/role/string()}</td>
           </tr>
         }
      </table>
     )
     else ()
     )
   }
   {bsa:list-selected-trips($bsa:trips[.//vessel/@charteredFrom=$query/id])}
   </div>
   {bsa:photo-selection(1)}
 </div>
};

(:  ------------------ News -------------------------------  :)
declare function bsa:list-news($query) {
  <div class="page">
    {for $item in doc(concat($bsa:db,"docs/news.xml"))/news/item
     order by $item/@date descending
     return 
      <div>
       <h3>{$item/title/string()}</h3>
       {$item/content/node()}
       <div><a href="{$item/link}">{$item/link/@title/string()}</a></div>
      </div>
    }
  </div>
};

(: ----------------- convert a trip to KML --------------------------- :)
declare function bsa:trip-to-kml($query as element(query)) as element(kml) {
 let $trip := bsa:trip($query/id)
 let $route := $bsa:routes/Route[id=$query/id]
 return
<kml>
  <Folder>
    <name>{bsa:trip-label($trip)}</name> 
     {
     for $wp in $route/wp
     let $description := 
     <div>
       <h3> {bsa:format-date($wp/@date)}&#160; {$wp/@time/string()}</h3>
       {bsa:annotation-context($wp,120)}
       <br/><a href="{$bsa:web-page}bsa.xq?mode=view&amp;type=Trip&amp;id={$trip/id}">Trip Report</a>
     </div>
     return
       <Placemark>
           <name>{$wp/@name/string()}</name>
           <description>{util:serialize($description,"method=xhtml media-type=text/html")}</description>
           <Point>
              <coordinates>{concat($wp/@long,",",$wp/@lat,",0")}</coordinates>
           </Point>
       </Placemark>
     }
     <Placemark>
       <name>Route</name>
       <LineString>
          <coordinates>
          {for $wp in $route/wp
           return 
              concat($wp/@long,",",$wp/@lat,",0")
          }
          </coordinates>
       </LineString>
     </Placemark>
  </Folder>
</kml>
};

(: convert all locations to KML :)
declare function bsa:locations-to-kml($query as element(query)) as element(kml) {
<kml>
  <Folder>
    <name>Locations</name> 
     {
     for $location  in $bsa:data//Location
     let $desc :=
     <div>
        {$location/description}
        <br/> <a href="{$bsa:web-page}bsa.xq?mode=view&amp;type=Location&amp;id={$location/name[1]}">Trips</a>
     </div>
     return
       <Placemark>
           {$location/name[1]}
           <description>{util:serialize($desc,"method=xhtml media-type=text/html")}</description>
           {$location/type} 
           <Point>
              <coordinates>{concat($location/long,",",$location/lat,",0")}</coordinates>
           </Point>
       </Placemark>
     }     
  </Folder>
</kml>
};

(: get the text from before and after a given node in the report. Typically this will be a wp element
:)

declare function bsa:annotation-context($node as node(),$n as xs:integer)  as element(div){
   let $nodesbefore := $node/preceding-sibling::node()
   let $nodesafter := $node/following-sibling::node()
   let $after := string-join($nodesafter, ' ')
   let $afterString := substring($after,1,$n)
   let $before := string-join($nodesbefore,' ')
   let $beforeString := substring($before,string-length($before)- $n + 1 ,$n)
   return
      <div>
          {concat('...', $beforeString,' ')} 
          <b>{$node/text()}</b>
          {concat($afterString,' ...')}
     </div>
};

declare function bsa:kml($query as element(query)) as element(kml)? {
  if ($query/type="Trip")
  then bsa:trip-to-kml($query)
  else if ($query/type="Location")
  then bsa:locations-to-kml($query)
  else ()
};


(:   ------------------  search ---------------------------- :)
declare function bsa:search($query as element(query)) as element(div) {
<div id="search" class="page">
 <form action="?">
  <input type="hidden" name="mode" value="search"/>
  <input type="text" name="q" value="{$query/q}" size="30"/>
  <input type="submit" value="search"/>
 </form>
 {if (exists($query/q) and $query/q ne "")
  then 
 <ul>
 {
    let $lq := <phrase>{$query/q/string()}</phrase>
    for $trip in ft:query($bsa:trips,$lq)
    let $label := bsa:trip-label($trip)
    order by $label
    return 
   <li><a href="?mode=view&amp;type=Trip&amp;id={$trip/id}">{$label}</a>
   <ul>
   {for $extract in kwic:summarize($trip,<config width="60"/>)
    return
       <li>{normalize-space($extract)}</li>
    }
   </ul>
   </li>
 } 
</ul>
  else ()
  }
</div>
};


(: -------------------- Trip editing ---------------------------- :)

declare function bsa:annotate-trip($query) {
    let $tripid := $query/id
    let $trip := bsa:trip($tripid)
    let $route := $bsa:routes/Route[id=$tripid]
    let $removeCache := if ($route) then update delete $route else ()  (: this might be premature if there are readers as well as editors :)
    let $annotations := $bsa:schema/entity[parent=("p","Trip")]
    return   
     <div class="page">
       <div><h3>{bsa:trip-label($trip)}</h3></div>
       <div id="info">
       {anot:render-with-annotations($trip/report/node(),$annotations)}
       </div>
       <div id="map_canvas" style="top:240px; height:400px;" />
       <div id="annotationData" style="top:650px;">
        {anot:form($tripid,$annotations)}
       </div>
     </div>  
};

declare function bsa:start-position ($trip as element(Trip)) {
let $wp := ($trip//wp)[1]
return 
   if (exists($wp/@lat))
   then
      ($wp/@lat/string(), $wp/@long/string())
   else
       ("50.8","-1.3")  (: this should be in data somewhere :)
};

(: ------------------------ Photo ----------------------------------------- :)

declare function bsa:view-photo($query) {
let $photo := $bsa:photoindex/photo[id = $query/id]
return
 <div class="page">
    <img src="{if (exists($photo/url)) then $photo/url else concat("photos/",$photo/id,".jpg")}"/>
    <div>
       {if ($photo/caption) then (<em>{$photo/caption/string()}</em>,<br/> ) else()}
       {$photo/photographer/string()} <br/>{$photo/place/string()}&#160;{$photo/date/string()}
    </div>
</div> 
};

declare function bsa:photo-selection ($n) {
<div id="photo" >
  { 
  let $photos := $bsa:photoindex/photo
  for $photo in 
         subsequence(for $photo in $photos
           order by  math:random()
           return $photo
         ,1,$n)
  return 
         <div class="photo" >
            <img src="{if (exists($photo/url)) then $photo/url else concat("photos/",$photo/id,".jpg")}"/>
            <div>
             {if ($photo/caption) then (<em>{$photo/caption/string()}</em>,<br/> ) else()}
             {$photo/photographer/string()} <br/>{$photo/place/string()}&#160;{$photo/date/string()}</div>
         </div>
  }
</div>  
};

declare function bsa:photo-selection ($n,$text) {
<div id="photo" >
  { 
  let $photos := $bsa:photoindex/photo[contains(.,$text)]
  for $photo in 
         subsequence(for $photo in $photos
           order by  math:random()
           return $photo
         ,1,$n)
  return 
         <div class="photo" >
            <img src="{if (exists($photo/url)) then $photo/url else concat("photos/",$photo/id,".jpg")}"/>
            <div>
             {if ($photo/caption) then (<em>{$photo/caption/string()}</em>,<br/> ) else()}
             {$photo/photographer/string()} <br/>{$photo/place/string()}&#160;{$photo/date/string()}</div>
         </div>
  }
</div>  
};

declare function bsa:list-photos($query) {
let $allphotos := $bsa:photoindex/photo
let $photos := subsequence(subsequence($allphotos,$query/start),1,$query/pagesize)
let $n := count($photos)
return
 <div class="page">
 <div>{ bsa:paging("?mode=list&amp;type=Photo", $query/start, $query/pagesize, count ($allphotos)) }</div>
   <table>
  { 
    for $row in 1 to 2
    return
    <tr>
    {
    for $col in 1 to 2
    let $i := ($row - 1 ) * 2  + $col
    let $photo := $photos[$i]
    return
         <td style="padding-right:30px;padding-left:30px; border:solid black 1px;">
            <a href="?mode=view&amp;type=Photo&amp;id={$photo/id}"> 
            <img src="{if (exists($photo/url)) then $photo/url else concat("photos/",$photo/id,".jpg")}"  width="350"/>
            </a>
            <div>
             {if ($photo/caption) then (<em>{$photo/caption/string()}</em>,<br/> ) else()}
             {$photo/photographer/string()} <br/>{$photo/place/string()}&#160;{$photo/date/string()}</div>
         </td>
    }
    </tr>
  }
  </table>
</div>  
};

declare function bsa:paging($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)?{
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  math:floor($start div $pagesize) + 1
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  return 
      if ($max eq 0) then ()
      else 
      <span class="paging">
       Page 
        {if ($prev-start ne $start)
       then <a href="{$url}&amp;start={$prev-start}&amp;pagesize={$pagesize}">Previous</a>
       else "          "}
        {for $i in (1 to $pages)
        let $start := xs:integer(($i - 1 ) * $pagesize + 1)
        return
          if ($i ne $page)
          then <a href="{$url}&amp;start={$start}&amp;pagesize={$pagesize}">{$i}</a>
          else concat("&#160;",$i,"&#160;")
       }
             {if ($next-start le $max)
       then <a href="{$url}&amp;start={$next-start}&amp;pagesize={$pagesize}">Next</a>
       else ()
       }
      </span>
};

declare function bsa:load-photo($query){
<div>
   <h3>Upload a photo</h3>
     <form enctype="multipart/form-data" method="post" action="?">
      <input type="hidden" name="mode" value="store"/>
      <input type="hidden" name="type" value="Photo"/>
      <fieldset><legend>Information about the photo</legend>
      <label for="caption">Caption </label><input type="text" name="caption" size="100"/><br/>
      <label for="date">Date</label><input type="text" name="date" size="20"/><br/>
      <label for="place">Place</label><input type="text" name="place" size="100"/><br/>
      <label for="vessel">Vessel</label><input type="text" name="vessel" size="100"/><br/>
      <label for="photographer">Photographer</label><input type="text" name="photographer" size="100"/><br/>
      </fieldset>
      <fieldset><legend>Photo</legend>
      <label for="file" title="640 x 480 is a good size - about 60Kb">Upload JPG</label> <input type="file" name="file" size="100"/><br/>
      </fieldset>
      <input type="submit" value="Upload"/>
     </form>
</div>
};

declare function bsa:store-photo($query as element(query)) {
 let $date := normalize-space(request:get-parameter("date",()))
 let $photographer := normalize-space(request:get-parameter("photographer",()))
 let $place := normalize-space(request:get-parameter("place",()))
 let $vessel := normalize-space(request:get-parameter("vessel",()))
 let $caption := normalize-space(request:get-parameter("caption",()))
 let $file := request:get-uploaded-file-data('file')
 return
    if (exists($file))
    then 
    let $login := xmldb:login($bsa:db,"admin","perdika")
    let $id := util:uuid()
    let $store := xmldb:store(concat($bsa:db,"photos"), concat($id,".jpg"), $file)
    let $photo :=
          <photo>
            <id>{$id}</id>
            <caption>{$caption}</caption>
            <photographer>{$photographer}</photographer>
            <vessel>{$vessel}</vessel>
            <place>{$place}</place>
            <date>{$date}</date>
            <user>{$query/user/string()}</user>
            <dateCreated>{current-dateTime()}</dateCreated>
         </photo>
   let $update :=  update insert $photo into $bsa:photoindex
   return  response:redirect-to(xs:anyURI(concat(request:get-uri(),"?mode=edit&amp;type=Photo")))      
   else
     response:redirect-to(xs:anyURI(request:get-uri()))
};

(: ------------------ Pages --------------------------- :)

declare function bsa:page($id) as element(div)* {
let $div := collection(concat($bsa:db,"docs"))/div[@id=$id]
return
<div class="page">
  <div id="leftside">
     {$div}
  </div>
  {bsa:photo-selection(2)}
</div>
};


declare function bsa:home($query) as element(div)* {

<div class="page">
  <div id="leftside">
     {collection(concat($bsa:db,"docs"))/div[@id="about"]}
     {if ($query/user) 
      then 
      <div>
        <h3>Admin functions </h3>
        <ul>
            <li> <a href="{$bsa:config/zipappresource}">View/Export Application code</a></li>
            <li> <a href="{$bsa:config/zipappdata}">View/Export Application data</a></li>       
        </ul>
      </div>
      else ()
     }
  </div>
  {bsa:photo-selection(2)}
</div>
};

(: ------------------- Main ------------------------ :) 
(:
  gather the URL parameters into an XML structure which is then passed around most functions
  to provide the context of the query.
:)

declare function bsa:query() as element(query) {
<query>
  <mode>{request:get-parameter("mode","home")}</mode>
  <type>{request:get-parameter("type",())}</type>
  <start>{request:get-parameter("start",1)}</start>
  <pagesize>{request:get-parameter("pagesize",4)}</pagesize>
  {if (exists(request:get-parameter("id",() )))
   then <id>{request:get-parameter("id",() )}</id>
   else ()
  }
  {if (session:get-attribute("user")) then <user>{session:get-attribute("user")}</user> else ()}
  <q>{request:get-parameter("q",())}</q>
  {if( exists(request:get-parameter("refresh",())))
   then <refresh/>
   else ()
  }
</query>
};

declare function bsa:menu($query as element(query)) as element(div) {
<div id="nav">
  <span>
     <span>{if (empty($query/type)) then attribute class {"highlight"} else () }<a href="?mode=home">Home</a></span> 
     <span>{if ($query/type="News") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=News">News</a></span> 
     <span>{if ($query/type="Trip") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Trip">Trips</a></span> 
     <span>{if ($query/type="Person") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Person">People</a></span> 
     <span>{if ($query/type="Vessel") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Vessel">Vessels</a></span> 
     <span>{if ($query/type="Location") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Location">Locations</a></span> 
     <span>{if ($query/type="Organisation") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Organisation">Organisations</a></span> 
     <span>{if ($query/type="Newsletter") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Newsletter">Newsletters</a></span> 
     <span>{if ($query/type="Photo") then attribute class {"highlight"} else () }<a href="?mode=list&amp;type=Photo">Photos</a></span> 
     <span><a href="?mode=search"> Search </a></span>  
     {if ($query/mode="edit" and $query/type="Trip" and exists($query/id)) 
      then (<span><a href="?mode=view&amp;type=Trip&amp;id={$query/id}">View</a></span>,
            <span><a href="?mode=try-delete&amp;type=Trip&amp;id={$query/id}">Delete</a></span>
           )
      else ()
     }
     {if ($query/mode="home" and exists($query/user))
      then  <span><a href="?mode=edit&amp;type=Photo">Load Photos</a></span>
      else ()
     }
     {if ($query/mode="view" and $query/type="Trip" and exists($query/id) and exists($query/user))
      then  <span><a href="?mode=edit&amp;type=Trip&amp;id={$query/id}">Edit</a></span>
      else ()
     }
     {if (empty($query/user)) then <span><a href="?mode=login-form">Login</a></span> else ()}
     {if (exists($query/user)) then  <span><a href="?mode=logout">Logout</a></span> else ()}
  </span>
</div>
};

declare function bsa:body($query as element(query)) as element(div)* {
let $mode := $query/mode
let $type := $query/type
return
if ($mode="search") then bsa:search($query)
else if ($mode="home") then bsa:home($query)  (: bsa:page("about") :)
else if ($mode="page") then bsa:page($query/id)
else if ($mode="list") then 
    if ($query/type = "Trip")
    then bsa:list-trips($query)
    else if ($query/type="Person")
    then bsa:list-persons($query)
    else if ($query/type="Vessel")
    then bsa:list-vessels($query)
    else if ($query/type ="Location")
    then bsa:list-locations($query)
    else if ($query/type ="Organisation")
    then bsa:list-organisations($query)
    else if ($query/type ="Newsletter")
    then bsa:list-newsletters($query)
    else if ($query/type ="Photo")
    then bsa:list-photos($query)
    else if ($query/type ="News")
    then bsa:list-news($query)
    else ()
else if ($mode="view") then 
    if ($query/type = "Trip")
    then bsa:view-trip($query)
    else if ($query/type="Person")
    then bsa:view-person($query)
    else if ($query/type="Vessel")
    then bsa:view-vessel($query)
    else if ($query/type="Location")
    then bsa:view-location($query)
    else if ($query/type="Organisation")
    then bsa:view-organisation($query)
    else if ($query/type="Newsletter")
    then bsa:view-newsletter($query)
    else if ($query/type="Photo")
    then bsa:view-photo($query)
    else ()
else if ($mode="kml") then bsa:kml($query)
else if ($mode="register-form") then bsa:register-form() 
else if ($mode="register") then bsa:register() 
else if ($mode="login-form") then bsa:login-form() 
else if ($mode="login") then bsa:login()
else if ($mode="logout") then bsa:logout()
else if ($mode="upload" and $type="Newsletter" and exists($query/user))then bsa:upload-newsletter($query)
else if ($mode="extract" and $type="Newsletter" and exists($query/user))then bsa:create-trip($query)
else if ($mode="store" and $type="Trip" and exists($query/user)) then bsa:store-trip($query)       
else if ($mode="edit" and $type="Trip" and exists($query/user))then bsa:annotate-trip($query) 
else if ($mode="edit" and $type="Photo" and exists($query/user))then bsa:load-photo($query) 
else if ($mode="store" and $query/type="Photo" and exists($query/user))then bsa:store-photo($query) 
else if ($mode="try-delete" and $type="Trip" and exists($query/user))then bsa:try-delete-trip($query) 
else if ($mode="delete" and $type="Trip" and exists($query/user))then bsa:delete-trip($query) 
else ()
};

declare function bsa:page() {
let $query := bsa:query()
let $body := bsa:body($query)
let $menu := bsa:menu($query)
let $logit := log:log-request("BSA","browse",$query/user)
return
if ($query/mode="kml")
then 
   let $serialize := util:declare-option("exist:serialize", "method=xml media-type=application/vnd.google-earth.kml+xml")
   return
      $body
   else 
 <html>
  <head>
    <title>Bristol Sailing Association</title>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <meta name="google-site-verification" content="wNOXv38RxxXFnUpVR_EsKqD9QAeeyp3o46P8lgJuTTA" />
    <link rel="stylesheet" type="text/css" href="css/bsa2.css" media="screen" /> 
    <link rel="stylesheet" type="text/css" href="css/bsa2-pr.css" media="print" /> 
    <link rel="shortcut icon" href="images/favicon.ico"/>
    <script type="text/javascript" src="jscript/sorttable.js"  charset="utf-8"></script>
    <script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script> 
    <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
    <script type="text/javascript" src="jscript/jquery.metadata.js"></script> 
    <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/jquery-ui.min.js"></script>
    {if ($query/mode=("view","list") and $query/type =("Trip", "Location"))
     then 
      <script type="text/javascript" src="jscript/viewmap.js"></script>
     else if ($query/mode="edit" and $query/type="Trip")
     then  
      (  <script type="text/javascript" src="jscript/editnotes.js"></script>,
         <script type="text/javascript" src="jscript/editmap.js"></script>,
      let $trip := bsa:trip($query/id)
      let $position := bsa:start-position($trip) 
      return 
     <script type="text/javascript">
        var mapconfig = {{
          canvas: "#map_canvas",
          centreLat: {$position[1]},
          centreLong: {$position[2]},
          centreZoom: 14,
          latitude:"#wp-lat", 
          longitude:"#wp-long",
          address:"#wp-name",
          searchurl: '{concat("xquery/search.xq?trip=",$trip/id,"&amp;name=")}'
          }};
     </script>
       )
     else if ($query/mode="extract")
     then <script type="text/javascript" src="jscript/create.js"></script>
     else ()
    }
  </head>
  <body>
     <div id="head">
       <table>
          <tr>
          <td><img  src="images/seascape.jpg"/>
           {$menu} 
          </td>
          <td><a href="?mode=home"><img src="images/BSALogo150a.gif" width="100px" alt="BSA logo" /> </a></td>
          </tr>
       </table>
      </div>
      <div id="content">
        {$body} 
     </div>
  </body>
</html>
};
