module namespace metar = "http://kitwallace.me/metar";

import module namespace math="http://exist-db.org/xquery/math";
import module namespace httpclient="http://exist-db.org/xquery/httpclient";

declare variable $metar:stations := collection("/db/apps/metar/locations")//Station[METAR_Station];

declare function metar:direction-to-compass ($dir as xs:decimal) as xs:string {
let $dp :=  $dir + 11.25 
let $dp := if ($dp >=360) then $dp - 360 else $dp
let $p := floor($dp div 22.5)+ 1
return 
  ("N","NNE","NE","ENE","E","ESE","SE" ,"SSE" ,"S", "SSW","SW","WSW","W", "WNW","NW","NNW","N")[$p]
};

declare function metar:vapour-pressure ($temp as xs:decimal) as xs:decimal {
 6.11 * math:power(10,7.5 * $temp div ($temp + 237.7))
};

declare function metar:humidity($temp as xs:decimal, $dew-point as xs:decimal) as xs:decimal {
 round(metar:vapour-pressure($dew-point) div metar:vapour-pressure($temp) * 100)
};

declare function metar:centigrade($temp-farenheit as xs:decimal) as xs:decimal {
   round((xs:decimal($temp-farenheit) - 32) * 5 div 9)
};

declare function metar:zero-pad($n) {
  if ($n < 10) then concat("0",$n) else $n
};

declare function metar:minutes($time) {
  let $t := tokenize($time,":")
  return xs:integer($t[1]) * 60 + xs:integer($t[2]) 
};

declare function metar:ampm-to-time ($ampm as xs:string) as xs:string {
   let $time := tokenize ($ampm," ")
   let $thm := tokenize($time[1],":")
   return if (not($thm[1] castable as xs:integer and $thm[2] castable as xs:integer)) then "00:00" else
   let $t :=  xs:integer($thm[1]) + xs:integer($thm[2]) div 60 
   let $t := if ($time[2]= "AM" and $t lt 12) then $t 
             else if ($time[2] = "AM" and $t ge 12) then $t - 12
             else if ($time[2] = "PM" and $t lt 12) then $t + 12 
             else if ($time[2] = "PM" and $t ge 12) then $t
             else ()
   let $h := floor($t)
   let $m := round(($t - $h) * 60 )
   return concat (metar:zero-pad($h),":",metar:zero-pad($m))
};

declare function metar:metar-to-xml($text as xs:string*, $icao as xs:string, $date as xs:date) as element(report)* {
   for $line in $text[position() > 1] [normalize-space() ne ""]
   let $data := tokenize(normalize-space($line),",")
   let $e := error((),"x",
    string-join(for $f at $i in $data
    return concat($i,":",$f),"-----")
    )
   let $temp := if ($data[2] castable as xs:decimal) then metar:centigrade(xs:decimal($data[2]))  else ()        
   let $dew-point :=if ($data[3] castable as xs:decimal) then  metar:centigrade(xs:decimal($data[3])) else ()
   let $report := 
     <report>
      <date>{$date}</date>
      <time>{metar:ampm-to-time($data[1])}</time>
      <icao>{$icao}</icao>
      <temp>{$temp}</temp>
      {if ($dew-point and $temp) 
             then (<dew-point>{$dew-point}</dew-point>,
                    <humidity>{metar:humidity($temp,$dew-point)}</humidity>
                  )
             else ()
       }
      {if ($data[5] castable as xs:decimal) then <pressure>{round(xs:decimal($data[5]) * 33.86)}</pressure> else ()}
      {if ($data[6] ne "-9999.0" and $data[6] castable as xs:decimal ) then element visibility {round(xs:decimal($data[6]) * 1.60934) } else () }
      <wind-direction-points>{$data[7]}</wind-direction-points>      
      <wind-direction-degrees>{$data[13]}</wind-direction-degrees>
      {if ($data[8] castable as xs:decimal and $data[8] ne "-9999.0") then <wind-speed>{round(xs:decimal($data[8]) div  1.15077945 )}</wind-speed> else ()}
      {if ($data[9] castable as xs:decimal) then <wind-gust-speed>{round(xs:decimal($data[9]) div  1.15077945 )}</wind-gust-speed> else ()}
      {if ($data[10] castable as xs:decimal) then <precipitation>{round(xs:decimal($data[10]) * 25.4)}</precipitation> else ()}
      {if ($data[11] ne '') then <events>{$data[11]}</events> else () }
      {if ($data[12] ne "Unknown") then <conditions>{$data[12]}</conditions> else () }
     </report>
    return $report
};

declare function metar:metric-metar-to-xml($text as xs:string*, $icao as xs:string, $date as xs:date) as element(report)* {
   for $line in $text[position() > 1] [normalize-space() ne ""]
   let $data := tokenize(normalize-space($line),",")
   let $temp := $data[2]       
   let $dew-point :=$data[3] 
   let $report := 
     <report>
      <date>{$date}</date>
      <time>{metar:ampm-to-time($data[1])}</time>
      <icao>{$icao}</icao>
      <temp>{$temp}</temp>
      {if ($dew-point castable as xs:double and $temp castable as xs:double) 
             then (<dew-point>{$dew-point}</dew-point>,
                    <humidity>{metar:humidity(xs:decimal($temp),xs:double($dew-point))}</humidity>
                  )
             else ()
       }
      <pressure>{$data[5]}</pressure>
      <visibility>{$data[6]}</visibility>
      <wind-direction-points>{$data[7]}</wind-direction-points>      
      <wind-direction-degrees>{$data[13]}</wind-direction-degrees>
      {if ($data[8] castable as xs:decimal and $data[8] ne "-9999.0") then <wind-speed>{round(xs:decimal($data[8]) *0.54 )}</wind-speed> else ()}
      {if ($data[9] castable as xs:decimal) then <wind-gust-speed>{round(xs:decimal($data[9]) * 0.54 )}</wind-gust-speed> else ()}
      {if ($data[10] castable as xs:decimal) then <precipitation>{round(xs:decimal($data[10]) * 25.4)}</precipitation> else ()}
      {if ($data[11] ne '') then <events>{$data[11]}</events> else () }
      {if ($data[12] ne "Unknown") then <conditions>{$data[12]}</conditions> else () }
     </report>
    return $report
};

declare function metar:get-metar($icao as xs:string, $date as xs:date )  as element(report)* {
   let $datex := replace ($date,"-","/")
   let $uri := concat("http://www.wunderground.com/history/airport/",$icao,"/",$datex,"/DailyHistory.html?format=1")
(:   let $e := error((),"x", $uri) :)
   let $page := httpclient:get(xs:anyURI($uri),false(),())
   return 
      if (exists($page//body))
      then 
         metar:metric-metar-to-xml($page//body/text(),$icao, $date)
      else ()
};

declare function metar:find-station($latitude as xs:decimal, $longitude as xs:decimal, $range as xs:decimal) as xs:string? {
   let $stations := $metar:stations
   let $nearest :=
      for $station in $stations
      let $dlat := xs:decimal($station/latitude) - $latitude
      let $dlong := xs:decimal($station/longitude) - $longitude
      let $distance := $dlat * $dlat + $dlong * $dlong
      where $distance < $range 
      order by $distance 
      return $station/ICAO/string()
   return $nearest[1] 
};

declare function metar:find-station($icao) as element(station)? {
   $metar:stations[ICAO=$icao]
};

declare function metar:report-at-time($reports, $time) as element(report) {
  let $tmins := metar:minutes($time)
  return
      (for $report in $reports
       let $mins := metar:minutes($report/time)
       let $diff := math:abs($mins - $tmins)
       order by $diff
       return $report
       )[1]
};

declare function metar:history-page($icao as xs:string,$date as xs:date) as xs:string {
   concat("http://www.wunderground.com/history/airport/",$icao,"/", datetime:format-date($date,'yyyy/MM/dd'),"/DailyHistory.html")
};