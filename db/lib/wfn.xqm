module namespace wfn= "http://kitwallace.me/wfn";

declare function wfn:average($nums as xs:decimal*) as xs:decimal? {
  if (exists($nums))
  then sum($nums) div count($nums)
  else ()
};

declare function wfn:value-in-ks($val as xs:double) {
   let $aval := math:abs($val)  (: this needs a sig putting back else its unsigned :)
   return 
      if ($aval > 1.0E9) then concat(string(round-half-to-even($val div 1.0E9,3)),"b")
      else if ($aval > 1.0E6) then concat(string(round-half-to-even($val div 1.0E6,3)),"m")
      else if ($aval > 1.0E3) then concat(string(round-half-to-even($val div 1.0E3,3)),"k")
      else $val
};

declare function wfn:between($x,$min,$max) {
  $x >= $min and $x <= $max
};

declare function wfn:BGR($max as xs:integer, $x as xs:integer?) as xs:string {
   let $x := ($x,0)[1]
   let $knee := $max * 0.4
   let $r := if ($x < $knee) then 0 else wfn:interpolate ($knee,0,$max,255,$x)
   let $g := if ($x < $knee) then wfn:interpolate (0,0,$knee,255,$x) else wfn:interpolate($knee,255,$max,0,$x)
   let $b := if ($x < $knee) then wfn:interpolate(0,255,$knee,0,$x) else 0
   return concat("#",wfn:int2-to-hex($r),wfn:int2-to-hex($g),wfn:int2-to-hex($b))
};

declare function wfn:camel-case-to-words ( $string as xs:string?)  as xs:string {
      if (upper-case($string) = $string) (:all uppercase letters :)
      then
         $string
      else
        concat(substring($string,1,1),
             replace(substring($string,2),'(\p{Lu})',
                        concat(" ", '$1')))     
};
 
declare function wfn:duration-as-ms($t) {
      round((minutes-from-duration($t) * 60 + seconds-from-duration($t)) * 1000 )
};

declare function wfn:exist-node-id-to-js-node-id($s as xs:string) as xs:string{
   concat("n-",replace($s,"\.","-"))
};

declare function wfn:external-host() {
  request:get-header("X-Forwarded-Host")
};

declare function wfn:index-of($nodes,$target) as xs:integer {    
  for $node at $i in $nodes
  return if ($node is $target) then $i else ()
};

declare function wfn:int-to-hex($n as xs:integer) as xs:string {
   if ($n <10) 
   then xs:string($n) 
   else  if ($n < 16)
   then ("A","B","C","D","E","F")[$n - 9 ]
   else "0"
};

declare function wfn:int2-to-hex($n as xs:integer) as xs:string {
  concat(wfn:int-to-hex($n div 16), wfn:int-to-hex($n mod 16))
};

declare function wfn:interpolate($x1 as xs:decimal,$y1  as xs:decimal,$x2  as xs:decimal,$y2  as xs:decimal,$x  as xs:decimal) as xs:integer{
  let $dx := $x2 - $x1
  let $dy := $y2 - $y1
  let $xp := $x - $x1
  let $yp := $xp * $dy div $dx 
  return xs:integer($y1 + $yp)
};

declare function wfn:is-even($n as xs:integer) {
  $n mod 2 = 0
};

declare function wfn:items-to-json($items) {
  concat(
      "{",
      string-join (
      for $item in $items
      return
        concat(name($item),': "', string($item),'"')
      , " , "
     ),
     "}" 
  )
};

declare function wfn:js-node-id-to-exist-node-id($s as xs:string) as xs:string{
   replace(substring-after($s,"n-"),"-",".")
};

declare function wfn:node-join($nodes,$sep) {
  if (count($nodes) > 1)
  then ($nodes[1],$sep, wfn:node-join(subsequence($nodes,2),$sep))
  else $nodes
};

declare function wfn:node-join($nodes,$sep1,$sep2) {
  if (count($nodes) > 2)
  then ($nodes[1],$sep1, wfn:node-join(subsequence($nodes,2),$sep1,$sep2))
  else if (count($nodes) =2)
  then ($nodes[1],$sep2,$nodes[2])
  else $nodes
};

declare function wfn:paging($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)?{
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  math:floor($start div $pagesize) + 1
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  return 
      if ($max eq 0) then ()
      else 
      <div class="paging">
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
      </div>
};


declare function wfn:paging-full($url as xs:string, $start as xs:integer, $pagesize as xs:integer, $max as xs:integer ) as element(div)?{
  let $pages := xs:integer(math:ceil($max div $pagesize) )
  let $page :=  math:floor($start div $pagesize) + 1
  let $prev-start := max(($start - $pagesize,1))
  let $next-start := $start + $pagesize
  return 
      if ($max eq 0) then ()
      else 
      <div class="paging">
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
      </div>
};

declare function wfn:permutations($items as item()*) as element(perm)+ {  
   let $itemElems := for $i in $items return <item>{$i}</item>
   return wfn:permutations-x($itemElems)
};
  
declare function wfn:permutations-x($items as element(item)*) as element(perm)+ {
   if (count($items) le 1) 
   then  element perm {$items}
   else 
      for $item in $items,
          $perm in wfn:permutations-x($items except $item)
      return element perm {($item,$perm/node())}    
 };

(:
  replacements is a sequence of:
      <replace find="ss" replace="rr"/>
:)
declare function wfn:replace($text,$replacements as element(replace)*) {
   if (empty($replacements))
   then $text
   else
      let $r := $replacements[1]
      let $rtext := fn:replace($text,$r/@find,$r/@replace) 
      return wfn:replace($rtext , subsequence($replacements,2))
};

declare function wfn:round($v as xs:decimal , $p as xs:integer) as xs:double {
    let $f := math:power(10,$p)
    return  round($v * $f) div $f
};

declare function wfn:round-attributes($e , $p as xs:integer)  {
   element  {node-name($e)}  {
       for $a in $e/@*
       return
           attribute {local-name($a)} {wfn:round($a,$p)}
     }
};

declare function wfn:split($s,$delimiter, $name, $fields) {
  let $d := tokenize($s,$delimiter)
  return
    element {$name} {
      for $field at $i in tokenize($fields,",")
      where $field ne ""
      return
         element {$field} {$d[$i]}
    }
};

declare function wfn:string-distance($arg1 as xs:string, $arg2 as xs:string) as xs:decimal {
let $range := (0 to string-length($arg1))
return
        wfn:string-distance(
               string-to-codepoints($arg1), 
               string-to-codepoints($arg2),
               1, 
               1,
               $range,
               1
          )
}; 

declare function wfn:string-distance($chars1 as xs:integer*, $chars2 as xs:integer*, $i1 as xs:integer, $i2 as xs:integer, $lastRow as xs:integer+, $thisRow as
        xs:integer+) as xs:decimal {
    if ($i1 > count($chars1)) 
    then 
        if ($i2 = count($chars2))
        then $thisRow[last()] 
        else wfn:string-distance($chars1, $chars2, 1, $i2 + 1, $thisRow, $i2 + 1 )
    else wfn:string-distance($chars1, $chars2, $i1 + 1, $i2, $lastRow, ($thisRow, min(($lastRow[$i1 +
        1] + 1, $thisRow[last()] + 1, $lastRow[$i1] + (if ($chars1[$i1] = $chars2[$i2]) then 0 else
        1) ) ) ) ) 
};

declare function wfn:string-pad($s as xs:string, $n as xs:integer) {
string-join(for $i in 1 to $n return $s,"")
};

declare function wfn:string-join($strings,$sep1,$sep2) {
 if (count($strings) > 1)
 then   concat(string-join($strings[position()<last()],$sep1),$sep2,$strings[last()])
 else $strings
};

declare function wfn:string-join($strings) {
  wfn:string-join($strings,", "," and ")
};

declare function wfn:substring-between($t,$start,$end) {
   normalize-space(substring-before(substring-after($t,$start),$end))
};

declare function wfn:upper-case-words ( $string as xs:string)  as xs:string {
       string-join(
            for $word in tokenize($string," ")
            return concat(upper-case(substring($word,1,1)),
                                lower-case(substring($word,2))
                                )
            ," "
            )
 } ;

(:
  replacements is a sequence of:
      <replace find="ss" replace="rr"/>
:)

declare function wfn:word-replace($text, $replacements as element(replace)*) {
   string-join(for $word in tokenize(normalize-space($text),"\s+")
               let $replacement := $replacements[@find=$word]/@replace
               return if ($replacement) then string($replacement) else $word
               ," "
               )
};

