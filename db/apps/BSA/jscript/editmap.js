var map;
var markers = [];
var marker;
var config;

function updatePosition(latlng,centreMap) {
  $(config.latitude).val( Math.round(latlng.lat()*10000) / 10000 );
  $(config.longitude).val( Math.round(latlng.lng()*10000) / 10000);
  if (centreMap) map.setCenter(latlng);
}
function setCentre() {
  var latlng = map.getCenter();
  marker.setPosition(latlng);
  $(config.latitude).val( Math.round(latlng.lat()*10000) / 10000 );
  $(config.longitude).val( Math.round(latlng.lng()*10000) / 10000);
}

function clearLatLong () {
  $(config.latitude).val('');
  $(config.longitude).val('');
}

function createMap (setup) {
  config = setup;
  var latlong = new google.maps.LatLng (config.centreLat, config.centreLong);
  var myOptions = {
     zoom: config.centreZoom,
     panControl: false,
     zoomControl: true,
     mapTypeControl: false,
     scaleControl: false,
     streetViewControl: false,
     overviewMapControl: false,
     center: latlong,
     mapTypeId: google.maps.MapTypeId.HYBRID
  }
  canvas = $(config.canvas).get(0);
   map = new google.maps.Map(canvas, myOptions);

   marker = new google.maps.Marker({
         position: latlong,
         draggable: true,
         map: map
        });
   google.maps.event.addListener(
         marker,
         'drag',
         function () {
             updatePosition(marker.getPosition(),false);
          }
       );
    google.maps.event.addListener(
         marker,
         'dragend',
         function () {
             updatePosition(marker.getPosition(),true);
          }
       );
    geocoder = new google.maps.Geocoder();
}

function findposition() { 
// latitude, longitude and name come from the form
  var lat = $(config.latitude).val();
  var long = $(config.longitude).val();
  var address = $(config.address).val();
  
  if (lat != "" && long != "") {
    var latlong = new google.maps.LatLng (lat, long );
    marker.setPosition(latlong);
    map.setCenter(marker.getPosition());
    map.setZoom(14);
  }
  else if (address != "") {
  // geocode the name  using the supplied search url  - response is in the form of a wp with attributes lat,long and name
  //  
  var url = config.searchurl.replace("&amp;","&")+address;
 // alert( url);
  var wp = $.ajax({
      url: url,
      async: false
     }).responseText;
  if (wp != '') {
            wp = $(wp);
            var latlng = new google.maps.LatLng (wp.attr('lat'), wp.attr('long'));
            marker.setPosition(latlng);
            map.setCenter(marker.getPosition());
            map.setZoom(14);
            updatePosition(latlng,true);
            $(config.address).val(wp.attr('name'));
   }
  else    
  geocoder.geocode(
     {'address':address} , 
      function(results,status) {
         if (status==google.maps.GeocoderStatus.OK) {
            var latlng = results[0].geometry.location;
            marker.setPosition(latlng);
            map.setCenter(marker.getPosition());
            map.setZoom(14);
            updatePosition(latlng,true);
          } else 
             alert("Geocoding "+address +" was not successful for the following reason: " + status);
      }
     );
  }
}

$(document).ready(function() {   
    initializeForm ();
    createMap(mapconfig);
  });