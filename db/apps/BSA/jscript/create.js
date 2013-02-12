
function selectText () {
   if (navigator.appName == 'Microsoft Internet Explorer') 
		selection = document.selection.createRange().text;
   else 
		selection= window.getSelection();
   if (selection.toString() =='') {alert("no text selected"); return false;}
   var range = selection.getRangeAt(0);
   var start = $(range.startContainer);
   var start = start.parent();
   var end = $(range.endContainer);
   var end = end.parent();
   $('#firstPara').val(start.attr('id'));
   $('#lastPara').val(end.attr('id'));
}
