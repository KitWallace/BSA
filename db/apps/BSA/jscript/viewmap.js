var map;
var infoWindow;
var markers = [];
var zoom = 12;

function handleClick (marker,i) {
  return function() {
     var html = $('#wp' + (i+1)).clone().show().get(0);
     infoWindow.setContent(html) ;
     infoWindow.open(map, marker);
     map.setCenter(marker.position);
     map.setZoom(zoom);
  }
}

function drawWaypoints() {
  var myOptions = {
     panControl: false,
     zoomControl: true,
     mapTypeControl: false,
     scaleControl: false,
     streetViewControl: false,
     overviewMapControl: false,
     mapTypeId: google.maps.MapTypeId.HYBRID
  }
  canvas = $("#map_canvas").get(0);
  map = new google.maps.Map(canvas, myOptions);
  infoWindow = new google.maps.InfoWindow ({ content:'Hello World' });
  var routeCoordinates = [];
  var bounds = new google.maps.LatLngBounds();
  $('#info .wp').each(function(index) {
     var data = $(this).metadata();
     var latlong = new google.maps.LatLng (data.lat, data.long );
     var wpicon = new google.maps.MarkerImage ("../images/lightblue"+(index + 1)+".png",
                  new google.maps.Size(17,19)
     );
     var marker = new google.maps.Marker({
         position: latlong,
         map: map,
         icon: wpicon,
         title: data.location,
         zIndex: 1000 - index
        });
     google.maps.event.addListener(
         marker,
         'click',
         handleClick(marker,index)
          );
     
     markers[index] = marker;
     routeCoordinates[index] = latlong;
     bounds.extend(latlong);

  });
  
  if (markers.length > 1)
        map.fitBounds(bounds); 
  else 
        {
         map.zoom=14; 
         map.center = markers[0].position;
         map.setCenter(map.center);
         map.setZoom(map.zoom);
        };
   
  if (markers.length > 1 && $('#info').hasClass('route')) {
     var routePath = new google.maps.Polyline({
         path: routeCoordinates,
         strokeColor: "#FF0000",
         strokeOpacity: 1.0,
         strokeWeight: 2
     });

     routePath.setMap(map);
      };
     

}

function addMarkerClicks () {
    $('.wp img').each(function(index) {
        $(this).click(function() {google.maps.event.trigger(markers[index],'click')})
       });
}

$(document).ready(function() {
    drawWaypoints();
    addMarkerClicks();
});
 