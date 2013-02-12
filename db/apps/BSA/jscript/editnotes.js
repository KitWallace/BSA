function isEmpty(str) {
  return str.replace(/^\s+|\s+$/g, '').length == 0;
}

// get the base data and then the subform data to construct the update URL
function sendupdate(action) {
   var url = "xquery/annotate.xq?action=" + action;
   $('#form').addClass('running');
   var form = $('#base > input').each(function(index) {
        val = $.trim($(this).val());
        if (val.length != 0) url+= '&'+ $(this).attr('name') + '=' + val;
        }); 
   var subform = $('.subform:visible input').each(function(index) {
        val = $.trim($(this).val());
        var fullname = $(this).attr('name');
        var name = fullname.split("-")[1];
        if (val.length != 0) url+= '&'+ name + '=' + val;
        }); 
//   alert(url);
   $.get(url,null, updatePage);
}

// the callback from the update 
// substitute the original element with the new xml using its id as the key
// this should test for and allow error returns - eg when server-side validation fails
function updatePage(xml, success, jqXHR) {
   if (xml != "") {
      var para = $(xml);  
      var id = para.attr('id');
      $('#'+id).replaceWith(para);
      setNoteClicks(); 
   }
   $('#form').removeClass('running');
}

// disable all buttons, and enable those with the listed ids
function activateButtons(ids) {
  $('.update').attr('disabled','disabled');  // disable all buttons
  for (var i=0;i < ids.length;i++)   {   
      $(ids[i]).removeAttr('disabled'); // remove the disable on the live buttons
     };
}

// called from a click on the annotation element , passing the id - which is the js form of the exist node id
// it copies data from the title attribute into the form and sets it up for editing 
function setSubform(id) {
  var note = $('#'+id);  // get the annotation element
  var data = note.metadata({type: 'attr', name: 'title'});   // get its data from the json encoded title attribute
  var tag = data.tag;   // get the tag 
  $('#container').val(id);   // set the container input in the form to the id 
  $('#text').val(note.text());  // take the text of the element and copy to the selected text field
  revealSubform(tag);  // make the subform for this tag visible 
//  alert (id);

  activateButtons(['#replace-button','#delete-button']);  // enable the replace and delete buttons
  $('.subform:visible input').val('');   // blank all the inputs fields in the visible subform
  for (name in data) {     // load the fields from the data
    $('#'+tag +'-' + name).val(data[name]);
  }
  
  //  execute any initialisation action  (eg to position the map ) by clicking the find button ??
  $('.subform:visible > button.find').trigger('click') ;
}

// add onclick to all annotations, passing the id of the node 
function setNoteClicks() {
   $('.note').each(function(index) {
        $(this).click(function() {setSubform($(this).attr('id'))
       });
    })
}

// add onclick to all subform buttons
function setSubformClicks() {
   $('.subform-button').each(function(index) {
        $(this).click(function() {selectSubform($(this).attr('name'))
       });
    })
}

// called when a button is pressed to get the selected text and populate the basic data in the form fields
// to allow the server-side script to substitute the selected text with an annotation node
function selectText () {
   if (navigator.appName == 'Microsoft Internet Explorer') 
		selection = document.selection.createRange().text;
   else 
		selection= window.getSelection();
   if (selection.toString() =='') {alert("no text selected"); return false;}
   var range = selection.getRangeAt(0);
   if (range.endContainer != range.startContainer ) {alert("text spans elements"); return false;};
   var textnode = $(range.startContainer);
   var container = textnode.parent();
   $('#container').val(container.attr('id'));
   $('#start').val(range.startOffset);
   $('#end').val(range.endOffset);
   $('#text').val(selection); 
   var nodeindex = 1, node = range.startContainer;
   while (node = node.previousSibling) {
         if (node.nodeType == 1 || (node.nodeType == 3 && !isEmpty(node.data))) ++nodeindex; }
   $('#nodeindex').val(nodeindex);
}

// make the subform visible and highlight the corresponding button
function revealSubform(tag){
   $('.subform').hide();
   $('#subform-'+tag).show();
   $('.subform-button').removeClass('selected');
   $('#button-'+tag).addClass('selected');     
   $('#tag').val(tag);  
}

// called from the subform button 
function selectSubform(tag) {
   revealSubform(tag);  
   selectText();
   $('.subform:visible input').val('');   // blank all the inputs fields in the visible  subform
   // need to put the selected text as the default value of any inputs in the selected (ie visible) subform with a class of 'is-selection'
   $('.subform:visible input.is-selection').val($('#text').val());
   activateButtons(['#add-button']); // can only add a new annotation here
}

function hideAll () {
   $('.subform').hide();
   activateButtons([]);
}

function clearForm() {
  $('#base input ').val('');  // blank all the fields in the base form
  hideAll();
}

function initializeForm (){
    hideAll();
    setNoteClicks();
    setSubformClicks();
}
