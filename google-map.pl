#!/usr/bin/perl

package Contour;

use strict;
use warnings;

use File::Basename qw(basename);
use JSON qw( decode_json );
use WWW::Curl::Easy;
use Data::Dumper;
use POSIX qw(ceil);
use List::MoreUtils qw( minmax );
use Getopt::Mixed "nextOption";
use Math::Trig qw(acos pi);

#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw(encpoly fetch);

# 7 points per hex, 50/3 m intervals

# w(theta) = cos(theta)^2 ?
# theta = |x - x_0| * pi / 2r, r = 50m, |x - x_0| <= r. if || = r, theta = pi/2 => cos(theta) = 0
# h_w(x) = sum_y(w(theta(y)) * h(y)) / sum_y(w(theta(y))) (weighted mean) 

$| = 1;
my $EXE = basename($0);

sub help {
    print "USAGE: $EXE --coords la,lo,la,lo,la,lo,la,lo [--water=waterlevel | -w=waterlevel] [--min offset]\n";
    print "where coords parameters are in clockwise order (top left, top right, bottom right, bottom left)\n\n";
    print "for example: $EXE --coords 60.21,24.77,60.21,24.97,60.01,24.97,60.21,24.97 --water=1\n\n";
    exit 1;
}


sub arrminmax {
    my @a = @_;
    my $min = 32768;
    my $max = -32767;
    foreach my $r (@a) {
        foreach my $v (@$r) {
            $min = $v if (defined $v && $min > $v);
            $max = $v if (defined $v && $max < $v);
        }
    }
    return ($min, $max);
}

sub base64 {
    my ($i, $last) = @_;
    return "" unless ($i);
    $i = unpack("N", pack("B32", substr("0" x 32 . $i, -32)));
    $i = 63 + (($last == 1 ? 0 : 32) | $i);
    return chr($i);
}

sub empty {
    my $a = join "", @_;
    return $a =~ /^0*$/;
}

sub encpoly {
    my $retval;
    foreach my $i (@_) {
	my $num = int(100000* $i);
	if ($num < 0) {
	    $num = ($num & 0xFFFFFFFF) ^ 0xFFFFFFFF;
	    $num = ($num << 1) | 1;
	} else {
	    $num = ($num << 1);
	}
	
	while ($num >= 0x20) {
	    my $i = (0x20 | ($num & 0x1f)) + 63;
	    $retval .= chr($i);
	    $num = $num >> 5;
	}
	$retval .= chr($num + 63);
    }
    return $retval;
}

sub expect {
    my ($val1, $val2, $msg) = @_;
    die "$msg: $val1 != $val2\n" unless ($val1 eq $val2);
}

sub selftests {
    my ($dxla, $dxlo, $dyla, $dylo) = @_[0..3];
    my @coords = @_[4..11];
    my @la = @coords[(0, 2, 4, 6)]; # |1 2|
    my @lo = @coords[(1, 3, 5, 7)]; # |4 3|
    my @zero = @coords[0..1];
    expect(encpoly(40.7), '_flwF', "BUG: Encoded polyline for 40.7 is wrong");
    expect(encpoly(-179.9832104), '`~oia@', "BUG: Encoded polyline for -179.9832104 is wrong");
    expect(encpoly(38.5), '_p~iF', "BUG: Encoded polyline for 38.5 is wrong");
    expect(encpoly(-120.2), '~ps|U', "BUG: Encoded polyline for -120.2 is wrong");
    expect(encpoly(-126.453), 'fzxbW', "BUG: Encoded polyline for -126.453 is wrong");
    expect(encpoly(43.252), '_t~fG', "BUG: Encoded polyline for 43.252 is wrong");
    expect(encpoly(-126.453,43.252), 'fzxbW_t~fG', "BUG: Encoded polyline for (-126.453,43.252) is wrong");
    expect(dotprod(1,0,1,0), 1, "dot product <(1,0),(1,0)>: ");
    my %l = ();
    $l{'lat'} = 60.248;
    $l{'lng'} = 24.841;
    my @h = resolve_hex(\%l, 60.248, 24.699, 0, .142/159, 1, 0);
    expect($h[0], 159, "resolve hex fails");
    @h = hexat(60.248, 24.699, 0, .142/159, 1, 0, 159);
    expect($h[0], 60.248, "Wrong latitude");
    expect($h[1], 24.841, "Wrong longitude");
    expect(int(100000*dotprod($dxla, $dxlo, $dyla, $dylo)), 0, "BUG: sanity check file for inner product <dx, dy> > 0.00001");
    @h = [];
    $h[0][0] = 1;
    $h[0][1] = -2;
    $h[1][0] = 3;
    $h[1][1] = 4;
    @h = arrminmax(@h);
    expect($h[0], -2, "arrminmax fail: ");
    expect($h[1], 4, "arrminmax fail: ");
    my @dx = ($dxla, $dxlo);
    my @dy = ($dyla, $dylo);
    my @last = hexat(@zero, @dx, @dy, 31999);
    %l = ('lng' => $zero[1], 'lat' => $zero[0]);
    my @test = resolve_hex(\%l, @zero, @dx, @dy);
    expect($test[0], 0, "Resolving hex from coordinates failed for (0,0)!");
    expect($test[1], 0, "Resolving hex from coordinates failed for (0,0)!");
    $l{'lng'} = $last[1];
    $l{'lat'} = $last[0];
    @test = resolve_hex(\%l, @zero, @dx, @dy);
    expect($test[0], 159, "Resolving hex from coordinates failed for (159,199)!");
    expect($test[1], 199, "Resolving hex from coordinates failed for (159,199)!");
    $l{'lng'} = $lo[3];
    $l{'lat'} = $la[3];
    @test = resolve_hex(\%l, @zero, @dx, @dy);
    expect($test[0], 0, "Resolving hex from coordinates failed for (0,199)!");
    expect($test[1], 199, "Resolving hex from coordinates failed for (0,199)!");
}

sub hexat {
    my ($la, $lo, $dxla, $dxlo, $dyla, $dylo, $n) = @_; # starts at hex (0,0) <=> ($la, $lo)
    my $y = int($n / 160.0);
    my $x = $n % 160 + .5 * ($y % 2);
#    print "hexat(): y = $y, x = $x\n";
#    print "hexat(): ", $la + $x * $dxla + $y * $dyla, ":", $lo + $x * $dxlo + $y * $dylo, "\n";
#    print "hexat(): ", $la, " + ", $x, " * ", $dxla, " + ", $y, " * ", $dyla, ":", $lo," + ",$x," * ",$dxlo," + ",$y," * ",$dylo, "\n";
    return ($la + $x * $dxla + $y * $dyla, $lo + $x * $dxlo + $y * $dylo);
}

sub resolve_hex {
#    print "resolve_hex(): ", Dumper(\@_);
    my ($location, $la, $lo, $dxla, $dxlo, $dyla, $dylo) = @_;
    my $lox = $$location{'lng'};
    my $lax = $$location{'lat'};
    my @relativeloc = coordsub($la, $lo, $lax, $lox);
#    print "resolve_hex(): \@relativeloc: ", Dumper(\@relativeloc);
    my $dist = sqrt(dotprod(@relativeloc, @relativeloc));
#    print "distance: $dist\n";
    my $det = dotprod($dxla, 0-$dxlo, $dylo, $dyla);
    my ($x, $y) = (0,0);
    my $lenx = sqrt(dotprod($dxla, $dxlo, $dxla, $dxlo));
    my $leny = sqrt(dotprod($dyla, $dylo, $dyla, $dylo));
    my $dx1 = $dxla/$lenx;
    my $dx2 = $dxlo/$lenx;
    my $dy1 = $dyla/$leny;
    my $dy2 = $dylo/$leny;
#    print "det vs prod: ", $det, " ", ($lenx * $leny), "\n";
#    print "$dxla $dxlo $dyla $dylo\n";
#    print "$dx1 $dx2 $dy1 $dy2\n";
#    print "theta: ", acos(dotprod($dxla, $dxlo, $dyla, $dylo)/$lenx/$leny)/pi*180, "\n";
#    print "theta: ", acos(dotprod($dx1, $dx2, $dy1, $dy2))/pi*180, "\n";
#    print "$dylo * $relativeloc[1] - $dyla * $relativeloc[0] = ";
    $x = $dylo * ($relativeloc[0])  - $dyla * $relativeloc[1];
#    print "$x\n";
    $x = $x / $det;
#    print "=> $x\n";
#    $relativeloc[0] = $relativeloc[0] - $x * $dxla;
#    $relativeloc[1] = $relativeloc[1] - $x * $dxlo;
#    print "$dxla * $relativeloc[1] - $dxlo * $relativeloc[0] = ";
    $y = $dxla * $relativeloc[1] - $dxlo * $relativeloc[0];
#    print "$y\n";
    $y = int(.5 + $y / $det);
#    print "=> $y\n";
    $x = int(.5 + $x - .5 * ($y % 2));
    my @rest = coordsub(hexat($la, $lo, $dxla, $dxlo, $dyla, $dylo, $y*160+$x), @relativeloc);
    $dist = sqrt(dotprod(@rest, @rest));
#    print "distance_r: $dist\n";
#    while ($x < 161 && $y < 201 && ($dist > $lenx || $dist > $leny)) {
#	print "dist $dist | $lenx : $leny \n";
#	my $currla = ($x - .5 * ($y % 2))*$dxla + $y*$dyla;
#	my $currlo = ($x - .5 * ($y % 2))*$dxlo + $y*$dylo;
#	my @rest = coordsub($currla, $currlo, @relativeloc);
#	my @prop = coordsub($dxla, $dxlo, @rest);
#	my $xpr = dotprod(@prop, @prop);
#	@prop = coordsub($dyla, $dylo, @rest);
#	my $ypr = dotprod(@prop, @prop);
#	if ($xpr < $ypr) {
#	    print "xpr: $xpr > ypr: $ypr $dist<< @rest\n";
#	    $x++;
#	} else {
#	    print "xpr: $xpr < ypr: $ypr $dist<< @rest\n";
#	    $y++;
#	}
#	@rest = coordsub($currla, $currlo, @relativeloc);
#	$dist = sqrt(dotprod(@rest, @rest));
#   }
#    unless ($det == 0) {
#	print "det: $det!\n";
#	$x = dotprod((0-$dyla)/$det, ($dylo)/$det, reverse @relativeloc);
#	$y = dotprod($dxla/$det, (0-$dxlo)/$det, reverse @relativeloc);
#    } else {
#	print "DET: $det!\n";
#    my $dx1 = $dxla/$lenx;
#    my $dx2 = $dxlo/$lenx;
#    my $dy1 = $dyla/$leny;
#    my $dy2 = $dylo/$leny;
#    $x = dotprod($dx1, $dx2, @relativeloc) / $lenx;
#    $y = dotprod($dy1, $dy2, @relativeloc) / $leny;
#    }
#    print "<$dxla $dxlo> $lenx <$dx1 $dx2>\n";
#    print "<$dyla $dylo> $leny <$dy1 $dy2>\n";
#    $x = $x - .5 * (int($y + .5) % 2);
#    print "hex number! ", $x, ", ", $y, " (before rounding)\n";
    die "bad hex number! ", $x, ", ", $y, " (before rounding) for $lax:$lox |$la:$lo|" if ($x < -.5 || $y < -.5 || $x > 161.5 || $y > 201.5);
    return ($x, $y);
}

sub dotprod {
    my ($x1, $y1, $x2, $y2) = @_;
    return ($x1 * $x2 + $y1 * $y2);
}

sub coordsub {
    my ($la1, $lo1, $la2, $lo2) = @_;
    return ($la2-$la1, $lo2-$lo1);
}

sub fetch {
    my $keyfile = shift;
    my @la = @_[(0, 2, 4, 6)]; # |1 2|
    my @lo = @_[(1, 3, 5, 7)]; # |4 3|
    my @dx = (($la[1] - $la[0])/159, ($lo[1] - $lo[0])/159); # the grid input is (0-159) x (0-199) 
    my @dy = (($la[3] - $la[0])/199, ($lo[3] - $lo[0] - 0.5*$dx[1])/199);
    print "dx = ", "(",$la[1]," - ",$la[0],")/158, ", $lo[1], " - ",$lo[0],")/158)\n";
    print "dy = ", "(",$la[3]," - ",$la[0],")/198, ", $lo[3], " - ",$lo[0], " - .5*", $dx[1], ")/198)\n";
    my @zero = ($la[0], $lo[0]); # hex (0,0) -> we start reading from (1,1)
    print "Zero ", $zero[0], ", ", $zero[1], "\n";
    print "dx ", join(":",@dx), ", dy ", join(":",@dy), "\n";
    print "Corners: (0,0)=", $la[0], " ", $lo[0], " (159,0)=", $la[1], " ", $lo[1], " (0,199)=", $la[3], " ", $lo[3], "\n\n";
    print "Corners: (1,1)=", join (":", hexat(@zero, @dx, @dy, 161), " (159,1)=",hexat(@zero, @dx, @dy, 319), " (1,199)=", hexat(@zero, @dx, @dy, 31841), " (159, 199)=", hexat(@zero, @dx, @dy, 31999)), "\n\n";
    selftests(@dx, @dy, @_);
    my @data;
    my ($resmin, $resmax);
    my ($resavg, $resdev, $rescount) = (0,0,0);

    open API, "$keyfile" || die "Can't get key: $!";
    my $key = <API>;
    chomp $key;
    close API;
    die "no key set" unless ($key && $key ne '');
    my $curl = WWW::Curl::Easy->new;
        
    $curl->setopt(CURLOPT_HEADER,1);
# max samples ~500 => let's take ~ 480 at a time
    my $samples = 159*3;
#    my $samples = 6;
    for (my $i = 0; $i < 199; $i+=3) {
	my $start = 160 * $i + 161; # 161 <=> (1,1)
	my @coord = hexat(@zero, @dx, @dy, $start);
	my @mid1 = hexat(@zero, @dx, @dy, $start+158); # 319 <=> (159,1)
	my @mid2 = hexat(@zero, @dx, @dy, $start+160+158); # <=> (159,2)
	my @mid3 = hexat(@zero, @dx, @dy, $start+160);
	my @mid4 = hexat(@zero, @dx, @dy, $start+320);
	my @end = hexat(@zero, @dx, @dy, $start+320+158);
#	print "route ", (join ':', @coord), " - ", (join ':', @mid1), " - ", (join ':', @mid2), " - ", (join ':', @mid3), " - ", (join ':', @mid4), " - ", (join ':', @end), "\n";
	$samples = 159*2 if ($i == 198);
	my $path = "https://maps.googleapis.com/maps/api/elevation/json?path=enc:" . 
	    encpoly(@coord) . 
	    encpoly(coordsub(@coord, @mid1)) .
	    encpoly(coordsub(@mid1, @mid2)) .
	    encpoly(coordsub(@mid2, @mid3)) .
	    ($i != 198 ? encpoly(coordsub(@mid3, @mid4)) : "") .
	    ($i != 198 ? encpoly(coordsub(@mid4, @end)) : "") .
	    "&samples=$samples&key=$key";
#	print $path, "\n";
	$curl->setopt(CURLOPT_URL, $path);

	my $response_body;
	$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
	
	my $retcode = $curl->perform;
	
        # Looking at the results...
	if ($retcode == 0) {
	    my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	    # judge result and next action based on $response_code
	    my @resp = split /\n\r?\n\r?/m, $response_body; 
	    $response_body = $resp[1];
	    open OUT, ">output.dump";
	    print OUT $response_body;
	    close OUT;
#	    print("Received response: $response_body\n") if (scalar(@resp) > 1);
	    my $json = decode_json($response_body);
	    my $status = $$json{'status'};
	    die "Error: $status" unless ($status eq 'OK');
	    my $results = $$json{'results'};
	    my @results = @$results;
	    foreach my $res (@results) {
		my $elevation = $$res{'elevation'};
		my $location = $$res{'location'};
		my $resolution = $$res{'resolution'};
		$resmin = $resolution if (!$resmin || $resolution < $resmin);
		$resmax = $resolution if (!$resmax || $resolution > $resmax);
		$resavg += $resolution;
		$resdev += $resolution*$resolution;
		$rescount += 1;
#		print "resolve ", Dumper($location), " from ", join (':', @zero), "\n";
		my ($x, $y) = resolve_hex($location, @zero, @dx, @dy);
#		print "($x, $y) -> $elevation [$resolution]\n";
		$data[$x][$y] = $elevation;
	    }
	    sleep 1 if ($i % 36 == 0 && $i != 198);
	} else {
	    # Error code, type of error, error message
	    print("An error happened: $retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n") && die "no luck";
	}
    }
    $resdev = $resmin == $resmax ? 0 : sqrt(($resdev/$rescount) - ($resavg*$resavg/$rescount/$rescount));
    $resavg = $resavg / $rescount;
    print "RESOLUTION: min: $resmin  max: $resmax  avg: $resavg  dev: $resdev\n\n";
    for (my $x = 1; $x < 160; $x++) {
	for (my $y = 1; $y < 200; $y++) {
	    print "Missing ($x,$y)" unless (defined $data[$x][$y]);
	}
    }
    return @data;
}

Getopt::Mixed::init( 'coords=s min:i w:i water>w');

my @coords;
my ($fmin, $water) = (5, 0);
while (my ($option, $value) = nextOption()) {
    print "$option => $value\n";
    if ($option eq 'coords') {
#	print "$option => $value\n";
	@coords = split /,/, $value;
#	print "@coords => ", join (",", @coords), "\n";
    } elsif ($option eq 'min') {
	$fmin = int($value);
    } elsif ($option eq 'w') {
	$water = $value;
    }
}
Getopt::Mixed::cleanup();

help() if (scalar(@coords) != 8);
map { unless (/^[+-]?((\d+(\.\d*)?)|(\.\d+))$/) { help(); } } @coords;

my @data = fetch("./google-api.key", @coords);

my ($min, $max) = arrminmax(@data);
my $fmax = 150;
print "Height info read: min $min, max $max\n";

print "Creating map\n";
open MAP, "<spmap999.src" or die "Can't open input map! $!";
binmode MAP;
open MAPOUT, ">/tmp/spmap999.dat" or die "Can't open output map! $!";
binmode MAPOUT;

$/ = 
read(MAP, my $buffer, 70726, 0);
print MAPOUT $buffer;

for (my $x = 1; $x < 159; $x++) {
    for (my $y = 1; $y < 199; $y++) {
	my $h = $data[$x][$y];
#	print "Read ($x, $y) ==> $h\n";
#        print "($x, $y) = $h\n" if ($x == 1 || $y == 1 || $x == 158 || $y == 198);
        my $c = $h; # * ($max-$min);
	if (defined $fmin) {
	    $c -= $fmin;
	} else {
	    $c -= $min if ($min > 0);
	}
        if ($c < 0) {
	    $c = 0;
        }
        if ($c > $fmax) {
	    $c = $fmax;
        }
# WATER HEX, variable length. Doesn't work right now.
#		my @waterhex = ("0x86", "0x00", "0x01", "0x08", "0x86", "0x00", "0x02", "0xFD", "0xFF");
#		foreach $c (@waterhex) {
#  	        	my $b = pack 'C', hex($c);
#       			print MAPOUT $b;             # Write the height
#		}
#		seek(MAP, 4, 1);             # move position by 4 bytes
	#       } else {
	{
	    use integer;
	    $c = $c / 10;
	}
	$c = $c > 15 ? 150 : 10*$c;
#	print "Writing ($x, $y) ==> $c\n";
	my $b = pack 'C', $c;
	print MAPOUT $b;             # Write the height
	seek(MAP, 1, 1);             # move position by 1 byte
	read(MAP, my $buffer, 3, 0); # read 3 bytes (height information followed by 3 bytes; supposedly a hex graphic tile and such. 00FF00FF == level 0 ground)
	print MAPOUT $buffer;        # write 3 bytes
#	}
    }
#	print "\n";

    read(MAP, my $buffer, 16, 0);
    print MAPOUT $buffer;
}

while (!eof(MAP)) {
  read (MAP, my $buffer, 1024, 0);
  print MAPOUT $buffer;
}
