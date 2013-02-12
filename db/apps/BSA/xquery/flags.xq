
declare variable $local:alphabet := 
<signals>
  <signal letter="A" phonetic="Alpha" meaning="I have a diver down: keep well clear at slow speed"/>
  <signal letter="B" phonetic="Bravo" meaning="I am taking in or discharging dangerous goods"/>
  <signal letter="C" phonetic="Charlie" meaning="Affirmative"/>
  <signal letter="D" phonetic="Delta" meaning="Keep clear of me: I am manoevering with difficulty"/>
  <signal letter="E" phonetic="Echo" meaning="I am altering course to starboard"/>
  <signal letter="F" phonetic="Foxtrot" meaning="I am disabled, communicate with me"/>
  <signal letter="G" phonetic="Golf" meaning="I require a pilot"/>
  <signal letter="H" phonetic="Hotel" meaning="I have a pilot on board"/>
  <signal letter="I" phonetic="India" meaning="I am altering my course to port"/>
  <signal letter="J" phonetic="Juliet" meaning="I am on fire and have dangerous cargo on board"/>
  <signal letter="K" phonetic="Kilo" meaning="I wish to communicate with you"/>
  <signal letter="L" phonetic="Lima" meaning="You should stop your vessel instantly"/>
  <signal letter="M" phonetic="Mike" meaning="My vessel is stopped and making no way through the water"/>
  <signal letter="N" phonetic="November" meaning="Negative"/>
  <signal letter="O" phonetic="Oscar" meaning="Man overboard"/>
  <signal letter="P" phonetic="Papa" meaning="All persons should report on board as the vessel is about to preceed to sea"/>
  <signal letter="Q" phonetic="Quebec" meaning="My vessel is healthy and I require free pratique"/>
  <signal letter="R" phonetic="Romeo" meaning="The way is off my ship"/>
  <signal letter="S" phonetic="Sierra" meaning="I am operating astern propulsion"/>
  <signal letter="T" phonetic="Tango" meaning="Keep clear of me: I am engaged in pair trawling"/>
  <signal letter="U" phonetic="Uniform" meaning="You are running into danger"/>
  <signal letter="V" phonetic="Victor" meaning="I require assistance"/>
  <signal letter="W" phonetic="Whisky" meaning="I require medical assistance"/>
  <signal letter="X" phonetic="X-Ray" meaning="Stop carrying out your intentions and watch for my signals"/>
  <signal letter="Y" phonetic="Yankee" meaning="I am dragging my anchor"/>
  <signal letter="Z" phonetic="Zebra" meaning="I require a tug"/>
</signals>;

declare function local:flag($letter,$h) {
  let $signal := $local:alphabet/signal[@letter=$letter]
  return
     if ($signal) 
     then <img src="http://www.anbg.gov.au/images/flags/signal/{lower-case($letter)}.gif"  height="{$h}" title="{$signal/@meaning}"/>
     else ()
};

declare function local:flags($line,$h) {
  for $i in (1 to string-length($line))
  let $letter := substring($line,$i,1)
  return <span>{local:flag(upper-case($letter),$h)}</span>
};

declare option exist:serialize "method=xhtml media-type=text/html";

let $message := request:get-parameter("message","Hello")
return
<html>
 <title>Signalling with Flags</title>

<body>
<a href="/">Bristol Sailing Association</a>
  <center>
  <h1>Signalling with <a href="http://en.wikipedia.org/wiki/International_maritime_signal_flags">maritime signal flags.</a></h1>
  <div>Enter one or more sentences. Each word will be displayed in flags on a separate line.  <br/> Mouse over a flag to see what it means.
  <br/><a href="?message=ABCDE+FGHIJ+KLMNO+PQRST+UVWXY+Z">Alphabet</a> &#160;  <a href="?message=Bristol Sailing Association">BSA</a> &#160; 
  </div>
     <div>
      <form action="?">
        <input type="text" name="message" value="{$message}" size="40"/>
        <input type="submit" name="action" value="flags"/>
      </form>
    </div>
    {if($message ne "")
     then 
  <div>
 
   {   
   for $paragraph in tokenize($message,"\.")
   return
   <div style="margin-top:60px;">
   {for $line in tokenize($paragraph," ")
    return
     <div> {local:flags($line,60)} </div>
   }
   </div>
   }
  </div>
     else ()
    }
  </center>

</body>
</html>