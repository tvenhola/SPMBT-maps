# SPMBT-maps user manual

SPMBT-maps is a tool to help you create good [WinSPMBT](http://www.shrapnelgames.com/Camo_Workshop/MBT/MBT_page.html) maps.

## Choosing a location

The map tool generates you a 160x200 hex map approximately 8000 meters wide and 8660 meters high containing the height
information as provided by Google API. The resolution of Google API is in general 152 meters: i.e. terrain features
that are finer than 3 hexes wide may get lost and must be filled in by hand where appropriate. However, that is the
lowest resolution and in some cases the overall result is better than this promise.

When you have a good candidate location you can use the WWW map service that contains cached OpenStreetMap tiles to
see how that map would be produced. You can either go straight to the [map interface](http://www.venhola.com/maps/geo.php)
defaulting in Helsinki, Finland suburbs or you can [enter your coordinates and map rotation.](http://www.venhola.com/maps/)
The map location and rotation may be easily adjusted later in the UI tool. Coordinates must be entered in WGS84 decimal format,
so S20.1 W8.05 is entered by typing in -20.1 and -8.05 respectively. Rotation is in degrees.

In the tool you can then do adjustments (some of them are hidden when they would have no effect)
* Move map: Drag (with mouse) by holding the left button
* Rotate map: Shift + Alt + drag (holding left button of your mouse)
* Zoom in: Double click / &#8862; button / mouse wheel scroll up
* Zoom out: &#8863; button / mouse wheel scroll down
* Redraw hex grid to current map center on screen according to map rotation: &#10011; button
* Rotate map to geographical north: &#8679; button
* Rotate map to hex grid west-east axis: &#10178; button
* Download current hex grid area: &#8681; button
* Get link to the map (for bookmarking, linking outside...): L button

When you zoom in long enough you start to see individual hexes and some of them will contain their hex grid coordinates to help
you fill the map.

## Working on the map

### Getting the terrain

After picking a good location so that all areas of interests are covered by the map click the Download button. Generating the
map will take about half a minute but you can continue to use the UI while waiting. When the source map is generated it should
be copied to game directory tiled "Maps". It will be map number 999 and will be overwritten by autosave if you work with any
other map in the WinSPMBT map editor.

After opening the map go to second page of tools (either by clicking the blue triangle or "n" key on your keyboard) and choose
clear keeping the current contour. Do not click on any hex but choose then Fill range button and enter 255 in. Then press the 
fill button and the terrain should be finished.

### Starting the hard work

After getting a fresh terrain map I usually start by drawing in the major roads. Zoom in the map enough to see the main roads
and their hexes with numbers such as (4,0) in them. These correspond to the coordinates in your map editor. After roads are in
the other terrain features are easier to place. Other sources of information such as Google Earth and maps containing terrain 
information (rough / impassable areas, grass, woods etc) may be helpful. OpenStreetMap might not contain accurate information
everywhere. Using two monitors is a major helper when making these maps.

Sometimes you find yourself in a situation where you can't replicate the features on the map you see with WinSPMBT map editor.
Especially intersections, bridges or built areas might provide hard to fill in. In these cases I have aimed to the closest
look and feel gamewise and tended to be more creative especially if the area in question is not an essential one considering
the location. So roads that squirm on the map edge may be replaced with woods where they would show up on the map.
