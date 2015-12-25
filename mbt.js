var rotateRe = function (coord) {
    var center = webMercator;
    var rot = ol.coordinate.rotate([(coord[0] - webMercator[0]), (coord[1] - webMercator[1])], rotation);
    return [(rot[0] + webMercator[0]), (rot[1] + webMercator[1])];
}

var addCoords = function (coord, vector) {
    return [(coord[0] + vector[0]), (coord[1] + vector[1])];
}

var hexat = function(location, compression, n) {
    s = 25*2/Math.sqrt(3);
    y = Math.floor(n/160);
    x = (n % 160) - 80 + 0.5 * (y % 2);
    y = y - 100;
    retval = new Array();
    for (i = 0; i < 6; i++) {
	dy = Math.cos(Math.PI * i / 3) * s;
	dx = Math.sin(Math.PI * i / 3) * s;
	retval[i] = rotateRe(new Array(location[0] + (x * 50 + dx) / compression, location[1] - (y * 1.5*s + dy)/compression));
    }
    return retval;
}

var centerButton = document.createElement('button');
centerButton.innerHTML = '&#10011;';
centerButton.title='Center hex grid here';
var centergrid = document.createElement('div');
centergrid.setAttribute('class', 'ol-control ol-unselectable center-grid');
centergrid.appendChild(centerButton);
/*  <input type="button" value="+" id="centergrid" class=".center-grid"/> */
centergrid.addEventListener('click', function() {
    webMercator = map.getView().getCenter();
    allLayers = createLayers();
    map.getLayers().clear();
    map.getLayers().extend(allLayers);
    currGridRotation = map.getView().getRotation();
    document.getElementById("coordinates").innerHTML = getCoordinatesAndRotationString(webMercator, map.getView().getRotation(), compression);
    orientgrid.setAttribute('style', 'visibility: hidden');
}, false);

var orientButton = document.createElement('button');
orientButton.innerHTML = '&#10178;';
orientButton.title='Orientate view to grid';
var orientgrid = document.createElement('div');
orientgrid.setAttribute('class', 'ol-control ol-unselectable orientate-to-grid');
orientgrid.setAttribute('style', 'visibility: hidden');
orientgrid.appendChild(orientButton);
/*  <input type="button" value="+" id="orientgrid" class=".orientate-to-grid"/> */
orientgrid.addEventListener('click', function() {
    var rotateAround = ol.animation.rotate({
	anchor: webMercator,
	duration: 200,
	rotation: rotation
    });
    map.beforeRender(rotateAround);
    map.getView().rotate(currGridRotation);
    orientgrid.setAttribute('style', 'visibility: hidden');
}, false);

var downloadButton = document.createElement('button');
downloadButton.innerHTML = '&#8681;';
downloadButton.title='Download map terrain file for current grid';
var download = document.createElement('div');
download.setAttribute('class', 'ol-control ol-unselectable download-map');
download.appendChild(downloadButton);
download.addEventListener('click', function() {
    var center = webMercator;
    var compr = compression;
    window.location="download.php?coords=" + ol.proj.toLonLat(hexcenter(center, compr, 0)).reverse() + "," +
	ol.proj.toLonLat(hexcenter(center, compr, 159)).reverse() + "," +
	ol.proj.toLonLat(hexcenter(center, compr, 31999)).reverse() + "," +
	ol.proj.toLonLat(hexcenter(center, compr, 31840)).reverse();
    alert('Generating map - it should take less than a minute');
}, false);

var linkButton = document.createElement('button');
linkButton.innerHTML = 'L';
linkButton.title='Link to this map grid';
var linkdiv = document.createElement('div');
linkdiv.setAttribute('class', 'ol-control ol-unselectable link-map');
linkdiv.appendChild(linkButton);
linkdiv.addEventListener('click', function() {
    var lola = ol.proj.toLonLat(webMercator);
    window.prompt("Copy to clipboard: Ctrl+C, Enter", 
		  'geo.php?lat=' + lola[1] + '&lo=' + lola[0] + "&rot=" + currGridRotation / 3.1415926 * 180);
}, false);

var hexcenter = function(location, compression, n) {
    retval = hexat(location, compression, n);
    retval[0][0] = (retval[0][0] + retval[3][0])/2;
    retval[0][1] = (retval[0][1] + retval[3][1])/2;
    return retval[0];
}

var getBoundingBox = function() {
    return Array(addCoords(
	hexat(webMercator, compression, 0)[3],
	ol.coordinate.rotate([-25/compression, 0], rotation)),
		 addCoords(
		     hexat(webMercator, compression, 159)[3],
		     ol.coordinate.rotate([50/compression, 0], rotation)),
		 addCoords(
		     hexat(webMercator, compression, 31999)[0],
		     ol.coordinate.rotate([25/compression, 0], rotation)),
		 addCoords(
		     hexat(webMercator, compression, 31840)[0],
		     ol.coordinate.rotate([-50/compression, 0], rotation))
		);
}


var geojsonObjectHexGrid = function(x,y) {
    var myGrid=Array(16);
    for (var i=0; i<4; i++) {
	for (var j=0; j<4; j++) {
	    myGrid[j+i*4] = hexgrid[4*x+j+(4*y+i)*160];
	}
    }
    return {
	'type': 'FeatureCollection',
	'crs': {
	    'type': 'name',
	    'properties': {
		'name': 'EPSG:3857'
	    }
	},
	'features': [
	    {
		'type': 'Feature',
		'geometry': {
		    'type': 'MultiPolygon',
		    'coordinates': [
			myGrid
		    ]
		}
	    },
	]
    };
}

var createLayers = function() {
    var newWGS = ol.proj.toLonLat(webMercator);
    compression = Math.cos(newWGS[1]*Math.PI/180);
    
    lrs = new Array(2002);
    
    hexgrid = new Array(32000);
    for (l = 0; l<32000; l++) {
	hexgrid[l] = hexat(webMercator, compression, l);
    }
    boundingbox = getBoundingBox();
    
    geojsonObject = {

	'type': 'FeatureCollection',
	'crs': {
	    'type': 'name',
	    'properties': {
		'name': 'EPSG:3857'
	    }
	},
	'features': [
	    {
		'type': 'Feature',
		'geometry': {
		    'type': 'MultiLineString',
		    'coordinates': [
			[boundingbox[0], boundingbox[1]],
			[boundingbox[2], boundingbox[1]],
			[boundingbox[0], boundingbox[3]],
			[boundingbox[2], boundingbox[3]],
		    ]
		}
	    },
	]
    };
    vectorSource = new ol.source.Vector({
	features: (new ol.format.GeoJSON()).readFeatures(geojsonObject)
    });

    vectorLayer = new ol.layer.Vector({
	source: vectorSource,
	style: [new ol.style.Style({
	    stroke: new ol.style.Stroke({
		color: 'black',
		width: 3,
            })
        })],
    });

    
    lrs[0] = new ol.layer.Tile({
	source: new ol.source.OSM({
	    attributions: [
		new ol.Attribution({
		    html: 'All maps &copy; ' +
			'<a href="http://www.openstreetmap.org/">OpenStreetMap</a>'
		}),
		ol.source.OSM.ATTRIBUTION
	    ],
	    crossOrigin: null
	})
    });
    lrs[1] = vectorLayer;
    for (l=2; l<2002; l++) {
	var piecey = (l-2) % 50;
	var piecex = Math.floor((l-2)/50);
	lrs[l] = new ol.layer.Vector({
	    minResolution: 0.2,
	    maxResolution: 8,
	    source: new ol.source.Vector({
		features: (new ol.format.GeoJSON()).readFeatures(geojsonObjectHexGrid(piecex,piecey)),
	    }),
	    style: new ol.style.Style({
		stroke: new ol.style.Stroke({
		    color: 'grey',
		    width: 1,
		}),
		text: new ol.style.Text({
		    font: 'Calibri',
		    text: "(" + (piecex*4) + ", " + (piecey*4) + ")",
		    fill: new ol.style.Fill({color: 'black'}),
		    stroke: new ol.style.Stroke({color: 'black', width: 1}),
		    offsetX: 0,
		    offsetY: 0
		}),
	    }),
	});
	lrs[l].setOpacity(.3);
    }
    return lrs;
}

roundCoordTo = function(numbers, decimals) {
  return [numbers[0].toFixed(decimals), numbers[1].toFixed(decimals)];
}

var getCoordinatesAndRotationString = function(center, rot, compr) {
  return "(0,0)-(159,0)-(159,199)-(0,199) [" + 
  roundCoordTo(ol.proj.toLonLat(hexcenter(center, compr, 0)),6) + 
  "]-[" + 
  roundCoordTo(ol.proj.toLonLat(hexcenter(center, compr, 159)),6) + 
  "]-[" + 
  roundCoordTo(ol.proj.toLonLat(hexcenter(center, compr, 31999)),6) + 
  "]-[" + 
  roundCoordTo(ol.proj.toLonLat(hexcenter(center, compr, 31840)),6) + 
  "]" + 
  ", Rotation: " + 
	(rot/Math.PI*180).toFixed(3) + 
  " deg";
}
