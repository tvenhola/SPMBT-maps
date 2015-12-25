<!DOCTYPE html>
<html>
<head>
<title>WinSPMBT Map Tool</title>
<script src="https://code.jquery.com/jquery-1.11.2.min.js"></script>
<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/css/bootstrap.min.css">
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.5/js/bootstrap.min.js"></script>
<link rel="stylesheet" href="v3.11.2/ol.css" type="text/css">
<script src="v3.11.2/ol.js"></script>
<style>
.rotate-north {
  top: 65px;
  left: .5em;
}
.ol-touch .rotate-north {
  top: 80px;
}
.center-grid {
  top: 45px;
  right: .5em;
}
.ol-touch .center-grid {
  top: 50px;
}
.orientate-to-grid {
  top: 75px;
  right: .5em;
}
.ol-touch .orientate-to-grid {
  top: 75px;
}
.download-map {
  top: 105px;
  right: .5em;
}
.ol-touch .download-map {
  top: 100px;
}
.link-map {
  top: 140px;
  right: .5em;
}
.ol-touch .link-map {
  top: 125px;
}
</style>
</head>
<body>
<div class="container-fluid">

<div class="row-fluid">
  <div class="span12">
    <div id="map" class="map"></div>
  </div>
</div>

</div>
<div id="coordinates"></div>
<script>
<?php
  $lo = $_REQUEST['lo'];
  $lat = $_REQUEST['lat'];
  $rot = $_REQUEST['rot'];
  if (!is_numeric($lo) || !is_numeric($lat) || abs($lo) > 180 || abs($lat) > 180 || !is_numeric($rot)) {
    $lo = 24.76831;
    $lat = 60.22095;
    $rot = 0;
?>alert('Invalid values, using defaults!');<?php
  }
  $rot = $rot / 180 * 3.1415926;
?>
var lonLat = [<? echo $lo; ?>,<? echo $lat; ?>];
var compression = Math.cos(lonLat[1]*Math.PI/180)
var webMercator = ol.proj.fromLonLat(lonLat);
var rotation = <? echo $rot; ?>;
var currGridRotation = rotation;

</script>
<script src="mbt.js"></script>
<script>
/**
 * Define a namespace for the application.
 */
window.app = {};
var app = window.app;

var gridControl = new ol.control.Control({element: centergrid});
var orientControl = new ol.control.Control({element: orientgrid});
var downloadControl = new ol.control.Control({element: download});
var linkControl = new ol.control.Control({element: linkdiv});

var boundingbox = getBoundingBox();

var image = new ol.style.Circle({
  radius: 5,
  fill: null,
  stroke: new ol.style.Stroke({color: 'red', width: 1})
});

var styles = {
  'Point': [new ol.style.Style({
    image: image
  })],
  'LineString': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'grey',
      width: 1
    })
  })],
  'MultiLineString': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'green',
      width: 1
    })
  })],
  'MultiPoint': [new ol.style.Style({
    image: image
  })],
  'MultiPolygon': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'grey',
      width: 1,
    }),
/*    fill: new ol.style.Fill({
      color: 'rgba(0, 0, 0, 0.025)'
    }),*/
    text: new ol.style.Text({
      font: 'Calibri',
      text: ".",
      fill: new ol.style.Fill({color: 'black'}),
      stroke: new ol.style.Stroke({color: 'black', width: 1}),
      offsetX: 0,
      offsetY: 0
    }),
  })],
  'Polygon': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'grey',
      width: 1
    }),
  })],
  'GeometryCollection': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'magenta',
      width: 2
    }),
    fill: new ol.style.Fill({
      color: 'magenta'
    }),
    image: new ol.style.Circle({
      radius: 10,
      fill: null,
      stroke: new ol.style.Stroke({
        color: 'magenta'
      })
    })
  })],
  'Circle': [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'red',
      width: 2
    }),
    fill: new ol.style.Fill({
      color: 'rgba(255,0,0,0.2)'
    })
  })]  
};

var styleFunction = function(feature, resolution) {
  return styles[feature.getGeometry().getType()];
};

var hexgrid = new Array(32000);
for (l = 0; l<32000; l++) {
  hexgrid[l] = hexat(webMercator, compression, l);
}


var geojsonObject = {};

var vectorSource = new ol.source.Vector({
  features: (new ol.format.GeoJSON()).readFeatures(geojsonObject)
});

var vectorLayer = new ol.layer.Vector({
  source: vectorSource,
  style: [new ol.style.Style({
    stroke: new ol.style.Stroke({
      color: 'black',
      width: 3,
		    })
		    })],
});

var allLayers = createLayers();

var map = new ol.Map({
  layers: allLayers,
  target: 'map',
  controls: ol.control.defaults({
    attributionOptions: /** @type {olx.control.AttributionOptions} */ ({
      collapsible: false
    })
  }),
  view: new ol.View({
    center: webMercator,
    zoom: 13,
    rotation: rotation
  })
});

map.addControl(gridControl);
map.addControl(orientControl);
map.addControl(downloadControl);
map.addControl(linkControl);
map.getView().on('change:rotation', function(event) { 
  rotation = map.getView().getRotation(); 
  orientgrid.setAttribute('style', 'visibility: visible');
		     
//  document.getElementById("coordinates").innerHTML = getCoordinatesAndRotationString(webMercator, rotation, compression);
});

document.getElementById("coordinates").innerHTML = getCoordinatesAndRotationString(webMercator, rotation, compression);

</script>
</body>
</html>
