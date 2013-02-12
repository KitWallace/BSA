module namespace anot = "http://kitwallace.me/anot";
import module namespace ui= "http://kitwallace.me/ui" at "/db/lib/ui.xqm";
import module namespace wfn= "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace date="http://kitwallace.me/date" at "/db/lib/date.xqm";

declare variable $anot:selection-entity  :=
    <entity name="Selection">
        <attribute name="tag" type="integer"/>
        <attribute name="start" type="integer"/>
        <attribute name="end" type="integer"/>
        <attribute name="container" type="string"/>
        <attribute name="nodeindex" type="integer"/>
        <attribute name="text"/>
     </entity>;

declare function anot:note-to-json($node) {
  concat(
      "{",
      string-join (
      (
       concat("tag:'",name($node),"'"),

       for $attr in $node/@*
       return
          concat(name($attr),': "', string($attr),'"')
       )
      , " , "
     ),
     "}" 
  )
};

declare function anot:js-node-id-to-exist-node-id($s as xs:string) as xs:string{
   replace(substring-after($s,"n-"),"-",".")
};

declare function anot:exist-node-id-to-js-node-id($s as xs:string) as xs:string{
   concat("n-",replace($s,"\.","-"))
};

declare function anot:add-annotation($doc, $annotations) {
    let $selection := ui:get-entity($anot:selection-entity)
    let $tag := $selection/tag
    let $start := xs:integer($selection/start)
    let $end := xs:integer($selection/end)
    let $nodeid :=  anot:js-node-id-to-exist-node-id($selection/container)
    let $container := util:node-by-id($doc,$nodeid)
    return if (empty($container)) then () else   
    let $nodes := $container/node()
    let $text := $nodes[xs:integer($selection/nodeindex)]
    let $text-before := substring($text,1,$start)
    let $selected-text := substring($text,$start+1, $end - $start)
    return if (string-length($selected-text)=0) then () else
    let $text-after := substring($text,$end + 1)
    let $annotation-model := $annotations[@name=$tag]
    let $annotation := ui:get-entity($annotation-model)
    return if (not(name($container) = $annotation-model/parent)) then () else
 (: the container is an allowable parent of the node to be inserted :)
    let $replace := 
         if ($annotation-model/@multiple)  
         then 
            let $str := $annotation/name
            let $str := if (ends-with($str,".")) then substring($str,1,string-length($str) - 1) else $str
            let $str := replace($str," and ",",")
            let $nodes := 
               for $part in tokenize($str,",")
               return
                 element {$annotation-model/@name/string()} {
                    attribute name {normalize-space($part)},
                    $part
                 }
             return wfn:node-join($nodes,", "," and ")
         else 
           element {$annotation-model/@name/string()} {
             for $attribute in  $annotation/*
             let $value := normalize-space($attribute)
             where $value ne ""
             return 
               let $name := name($attribute)
               let $def := $annotation-model/attribute[@name = $name]
               let $value := 
                   if ($def/compute)
                   then util:eval($def/compute)
                   else $value
               return
                   attribute {$name} {$value}
            , $selected-text
           }  
     let $newcontainer := 
      element {name($container)} { 
        $container/@*,
        $text/preceding-sibling::node(),
        $text-before, 
        $replace, 
        $text-after,
        $text/following-sibling::node()
       } 
     return 
        if (empty($newcontainer)) then () 
        else
          let $store := update replace $container with $newcontainer  
          return 
              util:node-by-id($doc,$nodeid)
};

declare function anot:delete-annotation($doc,$annotations) {
    let $selection := ui:get-entity($anot:selection-entity)
    let $nodeid := anot:js-node-id-to-exist-node-id($selection/container)
    let $annotation :=  util:node-by-id($doc,$nodeid)
    let $container := $annotation/parent::node()
    let $pnodeid := util:node-id($container)
    let $newcontainer := 
        element {name($container)} {
           $container/@*,
           $annotation/preceding-sibling::node(),
           $annotation/string(),
           $annotation/following-sibling::node()
       }
    let $undo := update replace $container with $newcontainer
    return 
         util:node-by-id($doc,$pnodeid)
};

declare function anot:replace-annotation($doc,$annotations) {
    let $selection := ui:get-entity($anot:selection-entity)
    let $tag := $selection/tag
    let $nodeid := anot:js-node-id-to-exist-node-id($selection/container)
    let $annotation :=  util:node-by-id($doc,$nodeid)
    return if (empty($annotation)) then () else
    let $annotation-model := $annotations[@name=$tag]
    let $annotation-data := ui:get-entity($annotation-model)
    return if ($tag  ne name($annotation)) then () else  (: can only replace one annotation by one of the same name :)
    let $replace := 
        element {$annotation-model/@name/string()} 
           {
            for $attribute in  $annotation-data/*
            let $value := normalize-space($attribute)
            where $value ne ""
            return 
               let $name := name($attribute)
               let $def := $annotation-model/attribute[@name = $name]
               let $value := 
                   if ($def/compute)
                   then util:eval($def/compute)
                   else $value
               return
                  attribute {$name} {$value}
           , $annotation/string()
           }       
    let $undo := update replace $annotation with $replace
    return 
        util:node-by-id($doc,$nodeid)
};

declare function anot:update-annotation($doc, $annotations) {
let $action := request:get-parameter("action", "add")
let $update := 
  if ($action = "add")
  then anot:add-annotation($doc, $annotations)
  else if ($action = "delete")
  then anot:delete-annotation($doc, $annotations)
  else if ($action = "replace")
  then anot:replace-annotation($doc, $annotations)
  else ()
return 
  if (exists($update))
  then anot:render-with-annotations($update, $annotations)
  else ()
};

declare function anot:render-with-annotations($items as node()*, $annotations) {
for $item in $items
let $entity := $annotations[@name=name($item)]
return 
   if ($entity)
   then anot:render-note($item, $entity, $annotations)
   else if ($item instance of element())
   then element {name($item)} {anot:render-with-annotations($item/node(), $annotations)}
   else if (normalize-space($item) ne "")
   then $item
   else ()
};

declare function anot:render-note($item, $entity, $annotations) {
let $classes := string-join(( if (exists($entity/attribute)) then "note" else (), $entity/@class)," ")
return
  element {$entity/@html} {
    attribute class {$classes},
    if (exists($entity/attribute)) 
    then 
       (attribute title {anot:note-to-json($item)},
        attribute id {anot:exist-node-id-to-js-node-id(util:node-id($item))}, 
        anot:render-with-annotations($item/node(), $annotations),
        if ($entity/@class="map") 
        then  <img src="../images/lightblue1.png" alt="Map"/>
        else ()
       )
    else 
      (attribute id {anot:exist-node-id-to-js-node-id(util:node-id($item))},
       anot:render-with-annotations($item/node(), $annotations)
      )
  }
};

declare function anot:form($docid, $annotations){
   <form id="form" action="?">
       <div id="base">
       <input type="hidden" name="docid" id="docid" value="{$docid}"/>
       <input type="hidden" name="container" id="container"/>
       <input type="hidden" name="nodeindex" id="nodeindex"/>
       <input type="hidden" name="start" id="start"/>
       <input type="hidden" name="end" id="end"/>
       <input type="hidden" name="tag" id="tag"/>
       <label for="text" title="selected Text">Text</label><input type="text" name="text" id="text" size="60"/>
       </div>
       {for $entity in $annotations[attribute]
        return
          <button type="button" class="subform-button" name="{$entity/@name}" id="button-{$entity/@name}" title="{$entity/comment}">{$entity/@title/string()}</button>
       }
       <hr/>
       {for $entity in $annotations[attribute]
        return
           let $fname := $entity/@name/string()
           return
               <div class="subform" id="subform-{$fname}">
                
                  {for $attribute in $entity/attribute
                   return 
                     <span>
                       <label for="{$fname}-{$attribute/@name}" title="{$attribute/comment}">
                        {if  ($attribute/@min ne "0") then attribute class {"required"} else ()}
                        {$attribute/@name/string()}
                       </label>
                      <input type="text" name="{$fname}-{$attribute/@name}" id="{$fname}-{$attribute/@name}" size="{$attribute/@size}">
                        {if ($attribute/@is-selection) then attribute class {"is-selection"} else ()}
                      </input> 
                     </span>
                  }
               {if ($entity/@class="map")  (: bit of a fudge :)
                then 
                   (<button type="button" class="find" onclick="findposition()">Find Location</button>,
                    <button type="button" class="find" onclick="setCentre()">Location at Centre</button>,
                    <button type="button" class="clear" onclick="clearLatLong()">Clear lat/long</button>
                   )
                else ()
               }
            </div>  
        }
       <br/>      
       <button type="button" class="update" id="add-button" onclick="sendupdate('add')" >Add</button>
       <button type="button" class="update" id="replace-button" onclick="sendupdate('replace')" >Replace</button>
       <button type="button" class="update" id="delete-button" onclick="sendupdate('delete')" >Delete</button>
       <button type="button" onclick="clearForm()">Clear Form</button>
   </form>
};
