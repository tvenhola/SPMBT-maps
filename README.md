# SPMBT-maps
Satellite height data to WinSPMBT map utility

Requirements:
Linux
Perl (5.?)
Perlmagick (imagemagick utility)
SRTM3 map data files from the region of your choice from http://dds.cr.usgs.gov/srtm/version2_1/SRTM3/

Installation:
Install the linux utlities perl and perlmagick:

Ubuntu and Debian:
sudo apt-get install perl perlmagick


Usage:
perl map.pl --la N60.215486 --lo E24.768715 --water=1 --min 5

Will generate a map (approximately) centered at N60.215486,E24.768715, will reduce the height by 5 meters and will (later) convert the hexes with height less than 1 to water hex.

There will also be a small scale image xx.gif which contains the raw data (unscaled) and the upscaled image x.gif which is used for hex conversion.

Load the map nr. 999 into Map Editor, set fill range to 255 and clear terrain leaving the height information intact using the fill. This will redraw the hexes properly. Enjoy!

ISSUES AND BUGS:
Water not yet implemented
Will work best on non-coastal areas (water)
Center of map may differ from specified location by some hexes
-w shorthand trouble
All the height data in hex are chosen by closest pixel which may cause unintended phenomena, i.e. artifacts in the map. Fix them by hand.
