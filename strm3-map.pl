#!/usr/bin/perl
use Image::Magick;
use Encode;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir :seekable /;
use File::Basename qw(basename);
use Getopt::Mixed "nextOption";
use Switch;
use POSIX qw(ceil);
use constant DATA_MISSING => -2048;
use constant PI => 3.141592654;
use constant SQRT7OVER2 => 1.870829;

$| = 1;
my $EXE = basename($0);
sub average{
        my($data) = @_;
        if (not @$data) {
                warn("Empty array\n");
		return 0;
        }
        my $total = 0;
        foreach (@$data) {
                $total += $_;
        }
        my $average = $total / @$data;
        return $average;
}


sub closure {
	my ($ref, $x, $y, $SRC_X, $SRC_Y, $min) = @_;
	my @dirs = qw (1 2 3 4);
	my @data = @$ref;
	my @results = ();
	foreach $dir (@dirs) {
		my $val = dct(\@data, $dir, $x, $y, $SRC_X, $SRC_Y);
		push @results, $val unless ($val eq DATA_MISSING);
	}
	if ($min <= @results) {
		return &average(\@results);
	} else {
		return DATA_MISSING;
	}
}

sub dct {
# dir is 1 = up-down, 2 = left-right, 3 = left top - right bottom, 4 = right top - left bottom
# DCT subtype II: X_k = SUM_{n=0}^{N-1}{x_n cos(pi / N * (n + ½)k)}, k = 0, ..., N-1
	my ($ref, $dir, $x, $y, $SRC_X, $SRC_Y) = @_;
#	print "DCT for $x, $y; dir $dir\n";
	my @data = @$ref;
	my ($count, $dx, $dy) = (0,0,0);
	my @X;
	my @n = qw (-3 -2 -1 1 2 3);
	if ($dir eq 2 || $dir eq 3) {
		$dx = 1;
	} else {
		if ($dir eq 4) {
			$dx = -1;
			$dy = 1;
		}
	}
	$dy = 1 if ($dir eq 1 || $dir eq 3);
#	print "DIR $dir $dx,$dy\n";
	# We only count k = 2, 4, 6 because of coefficients and because cos(pi/7*3.5*n) != 0 only if n is even
	foreach my $k (qw (2 4 6)) {
		$count = 0;
		my $sum = 0;
		foreach $i (@n) {
			my $cx = $x + $i * $dx;
			my $cy = $y + $i * $dy;
#			print "$cx < 0 || $cx > $SRC_X || $cy < 0 || $cy > $SRC_Y\n";
			unless ($cx < 0 || $cx >= $SRC_X || $cy < 0 || $cy >= $SRC_Y) {
#				print "-> $cx, $cy = ", $data[$cx][$cy], " k=$k dir=$dir $dx,$dy\n";
				return DATA_MISSING if ($data[$cx][$cy] eq DATA_MISSING);
				$count++;
#				print "++ ", cos(PI/7*($i+3.5)*$k), "\n";
				$sum += $data[$cx][$cy] * cos(PI/7*($i+3.5)*$k);
			}
		}
#		print "sum_", $k, " = $sum\n";
		if ($count eq 0) {
			return DATA_MISSING; # Better safe than sorry
		} else {
			$X[$k] = $sum * 6 / $count * ($k/12); #Average out if we're on a border or there is data missing. Add coefficients to penalize high frequencies
		}
	}
#	print "$dir returns ", ($X[2] - $X[4] + $X[6]), " as value\n";
#	print "X_2 = ", $X[2], " X_4 = ", $X[4], " X_6 = ", $X[6], "\n";
	return ($X[2] - $X[4] + $X[6]);
}

sub conditionaladd {
	my ($val, $x, $y, $SRC_X, $SRC_Y) = @_;
	my @retval = (0, 0);
	print "MISS $x $y $val\n" if ($val eq DATA_MISSING);
	print "X OUT $x $y\n" if ($x < 0 || $x > $SRC_X);
	print "Y OUT $x $y\n" if ($y < 0 || $y > $SRC_Y);
	return @retval if ($x < 0 || $x > $SRC_X || $y < 0 || $y > $SRC_Y || ($val eq DATA_MISSING));
	return ($val, 1);
}

sub gethgtfile {
  my ($mainfile, $dir) = @_;
  my ($sn, $la, $we, $lo) = $mainfile =~ m/^([SN])(\d+)([WE])(\d+)\.hgt$/;
  my $format = "%s%02d%s%03d.hgt";
  print "DEBUG: SN $sn la $la WE $we lo $lo dir $dir mainfile $mainfile format $format\n";
  switch ($dir) {
    case 1 { return sprintf($format, $sn, $la, $we, (int($lo) + 1)); };
    case 2 { return sprintf($format, $sn, (int($la) + 1), $we, $lo); }; 
    case 3 { return sprintf($format, $sn, (int($la) + 1), $we, (int($lo) + 1)); };
  }
  die "Bad input @ gethgtfile: $mainfile, $dir\n";
}

sub help {
    print "USAGE: $EXE --la latitude --lo longitude [--water=waterlevel | -w=waterlevel] [--min offset]\n\n";
    print "for example: $EXE --la N60.21 --lo E24.77 --water=1\n\n";
    exit 1;
}

my %colormap = (
-1 => [0,0,255],
0 => [128,0,0],
1 => [160,0,0],
2 => [192,0,0],
3 => [255,0,0],
4 => [96,96,0],
5 => [128,128,0],
6 => [128,160,0],
7 => [128,192,0],
8 => [128,255,0],
9 => [96,96,128],
10 => [128,128,128],
11 => [160,128,128],
12 => [192,128,128],
13 => [255,128,128],
14 => [128,160,128],
15 => [128,192,128],
16 => [128,255,128] );

foreach my $foo (keys %colormap) {
        my @color = @{$colormap{$foo}};
	my @newcolor = map { $_ * 257 } @color;
	$colormap{$foo} = \@newcolor;
}
#print Dumper(\%colormap);

my $INT_SIZE = 2;
my $BUFFER_SIZE = 36;
my $IMAGE_X = 1604;
my $IMAGE_Y = 1736;
my $GEOMETRY = $IMAGE_X . "x" . $IMAGE_Y;
my $ARC_SECOND_COMPRESSION = -1;   # because x and y arent equal in source data
my $SRC_X = 86;   # WILL BE REWRITTEN LATER UNLESS ON EQUATOR. 86 pixels @ 92.61 m/px = 7964.5 m (160 hex @ 50m = 8000 m)
my $SRC_Y = 93;  # 200 hex @ 50m @ 30deg angle = 200 * 50 m * 0.866 = 8660 m @ 92.61 m/px = 93.5 px => 93 px == 8612.7 m

my @data = ();

Getopt::Mixed::init( 'la=s lo=s min:i w:i water>w');

my ($la, $lo, $force_min, $water) = (0, 0, 5, 0);
my $hgtfile = "";
my ($lax, $lox);

while (($option, $value) = nextOption()) {
  print "$option => $value\n";
  if ($option eq 'la') {
    if ($value =~ /^N\d{1,2}(\.\d*)?$/) {
      $la = $value;
      $lax = substr $la, 1;
      $ARC_SECOND_COMPRESSION = cos(int($lax)/180.0*3.1415927); # X is compressed by this much => more resolution near poles
      $lax += $SRC_Y / 2402; # center of map, not edge, so we move the pointer
      $hgtfile = "N" . int($lax) . $hgtfile;
      $lax = 1 - $lax + int($lax);
    } else {
      if ($value =~ /^S\d{1,2}(\.\d*)?$/) {
	$la = $value;
	$lax = substr $la, 1;
        $ARC_SECOND_COMPRESSION = cos(int($lax)/180.0*3.1415927);
	$lax += $SRC_Y / 2402; # center of map, not edge, so we move the pointer, but uncompressed units again
	$hgtfile = "S" . int($lax) . $hgtfile;
	$lax = $lax - int($lax);
      } else {
	help();
      }
    }
  }
  if ($option eq 'lo') {
    die ("Must specify latitude before longitude") if ($ARC_SECOND_COMPRESSION == -1);
    if ($value =~ /^W\d{1,2}(\.\d*)?$/) {
      $lo = $value;
      $lox = substr $lo, 1;
      $SRC_X = $SRC_X / $ARC_SECOND_COMPRESSION;
      $lox += $SRC_X / 2402; # center of map, not edge, so we move the pointer
      $hgtfile .= "W" . sprintf("%03d", int($lox));
      $lox = 1 - $lox + int($lox);
    } else {
      if ($value =~ /^E\d{1,2}(\.\d*)?$/) {
	$lo = $value;
	$lox = substr $lo, 1;
        $SRC_X = $SRC_X / $ARC_SECOND_COMPRESSION;
        $lox -= $SRC_X / 2402; # center of map, not edge, so we move the pointer
        $hgtfile .= "E" . sprintf("%03d", int($lox));
	$lox = $lox - int($lox);
      } else {
	help();
      }
    }
  }
  if ($option eq 'min') {
    $force_min = int($value);
  }
  if ($option eq 'w') {
    $water = $value;
  }
}
Getopt::Mixed::cleanup();

print "DEBUG: $hgtfile";

help() if (!($hgtfile =~ /[SN]\d{2}[WE]\d{3}/));

$hgtfile = $hgtfile . ".hgt";

print "Parameter values: la: ", $la, " lo: ", $lo, " min: ", $force_min, " water: ", $water, " hgtfile: ", $hgtfile, "\n";
print "DEBUG: lax: $lax lox: $lox\n";


open (FILE0, "<$hgtfile") or die "Can't open $hgtfile: $!";
binmode FILE0;

# 60.1850427,24.8280551
# 60.1491016,24.9487658
#
#my $la = .85-90/1201;#.5249106;
#my $lo = 1-300/1201;#.7910726;
# 60.2331435,24.7354169
# Kaitalampi 60.31942, 24.66230
# Lauttasaari 60.16348, 24.87158
# KehäII / Turunväylä 60.20493, 24.74612
# Karamalmi 60.21953, 24.76694
# Keha I / 110 => .21956 .81646
#my $la = 60.20493;
#my $lo = 24.74612;

print "DEBUG longitude [" . int($lox*1201) . "-". int($lox*1201+$SRC_X) ."]\n";
print "DEBUG latitude [" . int($lax*1201) . "-". int($lax*1201+$SRC_Y) ."]\n";
print "DEBUG longitude [", $lox, "-". ($lox*1201+$SRC_X)/1201 ."]\n";
print "DEBUG latitude [", $lax, "-". ($lax*1201+$SRC_Y)/1201 ."]\n";

# bit positions, 00 = everything in FILE0, 01 = adjacent in east, 10 = adjacent in south, 11 = spread to four files
my $gridcheck = 0; 

$gridcheck += 2 if (int($lax*1201+$SRC_Y) > 1201);
$gridcheck += 1 if (int($lox*1201+$SRC_X) > 1201);

print "DEBUG: grid check: $gridcheck\n";

my $xlimit = 1202;
my $ylimit = 1202;

if (($gridcheck & 1) == 1) {
  my $filename = gethgtfile($hgtfile, 1);
  print "DEBUG: opening another file $filename\n";
  open (FILE1, "<$filename") or die "Can't open $filename: $!";
  $xlimit = $SRC_X - (int($lox*1201+$SRC_X) - 1201);
  print "DEBUG: X limit: $xlimit src_x: $SRC_X right edge: ", int($lax*1201+$SRC_X), "\n";
}
if (($gridcheck & 2) == 2) { 
  my $filename = gethgtfile($hgtfile, 2);
  print "DEBUG: opening another file $filename\n";
  open (FILE2, "<$filename") or die "Can't open $filename: $!";
  $ylimit = $SRC_Y - (int($lax*1201+$SRC_Y) - 1201); 
}
if (($gridcheck & 3) == 3) {  
  my $filename = gethgtfile($hgtfile, 3);
  print "DEBUG: opening another file $filename\n";
  open (FILE3, "<$filename") or die "Can't open $filename: $!";
}

$min = 32768;
$max = -32767;
seek FILE0, $INT_SIZE*(1201*int($lax*1201) + int($lox*1201)), 0;
for (my $y=0; $y < $SRC_Y; $y++) {
  for (my $x=0; $x < $SRC_X; $x++) {
    my $readin;
    if ($xlimit > $x) {
      if ($ylimit > $y) {
	seek FILE0, $INT_SIZE*(1201*int($lax*1201 + $y) + int($lox*1201) + $x), 0;
	die "Can't read file: $! <" . FILE0 unless ( read FILE0, $readin, $INT_SIZE );
      } else {
	seek FILE2, $INT_SIZE*(1201*int($lax*1201 + $y - 1201) + int($lox*1201) + $x), 0;
	die "Can't read file: $! <" . FILE2 unless ( read FILE2, $readin, $INT_SIZE );
      }
    } else {
      if ($ylimit > $y) {
	seek FILE1, $INT_SIZE*(1201*int($lax*1201 + $y) + int($lox*1201) + $x - 1201), 0;
	die "Can't read file: $! <" . FILE1 unless ( read FILE1, $readin, $INT_SIZE );
      } else {
	seek FILE3, $INT_SIZE*(1201*int($lax*1201 + $y - 1201) + int($lox*1201) + $x - 1201), 0;
	die "Can't read file: $! <" . FILE3 unless ( read FILE3, $readin, $INT_SIZE );
      }
    }
    my $int16 = unpack 'n', $readin;
    $int16 = $int16-65536 if ($int16 > 32767);
#    print "fuu? ($x, $y) -> $int16  || ($SRC_X, $SRC_Y)\n" if ($int16 < -20 || $int16 > 100);
    $int16 = DATA_MISSING if ($int16 < -32000);
    $data[$x][$y] = $int16;
    $min = ($int16 < $min && $int16 != DATA_MISSING) ? $int16 : $min;
    $max = $int16 > $max ? $int16 : $max;
  }
}
print "Height info read: min $min, max $max\n";
my @data_new = map { [@$_] } @data; # good enough copy for us
my $updated = 1;
my $upddirmin = 4; 
my $missing = 1;
while ($upddirmin > 0 && $missing > 0) {
	$updated = 0;
	$missing = 0;
	for (my $y=0; $y < $SRC_Y; $y++) {
        	for (my $x=0; $x < $SRC_X; $x++) {
			if ($data[$x][$y] == DATA_MISSING) {
				$data_new[$x][$y] = closure(\@data, $x, $y, $SRC_X, $SRC_Y, $upddirmin);
#				print "Replacing missing data from (",$x,",",$y,") =>" . $data_new[$x][$y] . "\n";
				if ($data_new[$x][$y] == DATA_MISSING) {
				  $missing++;
				} else {
				  $updated++;
				}
			}
		}
	}
	print "$updated missing items updated at level $upddirmin","/4\n" if ($updated);
	@data = @data_new;
	@data_new = map { [@$_] } @data; # good enough copy for us
	if ($updated eq 0) {
		print "Stepping down a level\n";
		$upddirmin--;
	} else {
		print "Restart from top\n";
		$upddirmin = 4;
	}
}
print "Missing data replaced\n";
if ($missing > 0) {
  print "Unable to replace $missing items, expect some unexpected behaviour\n";
  print "Missing: ";
	for (my $y=0; $y < $SRC_Y; $y++) {
        	for (my $x=0; $x < $SRC_X; $x++) {
			if ($data[$x][$y] == DATA_MISSING) {
				$data[$x][$y] = $min;
				print "($x, $y), ";
			}
		}
	}
  print "\n";
}

#print Dumper(\%colormap);

my $image = Image::Magick->new(size=>(int($SRC_X)."x".int($SRC_Y)));
$image->ReadImage('canvas:black');
#$image->Set(background=>'white');
for (my $y=0; $y<$SRC_Y; $y++) {
	for (my $x=0; $x<$SRC_X; $x++) {
		my $c = ($data[$x][$y] - $min - $force_min)/($max-$min);
		$c = ($c < 0 ? 0 : $c);
		$image->SetPixel(x=>$x,y=>$y,color=>[$c, $c, $c]);
	}
#        print "\n" if ($y < 40);
}
$x = $image->Write('xx.gif');
warn "$x" if "$x";

print "Image created\n";
$image->Set(magick=>'RGB');
$image->Set( Gravity => 'Center' );
$image->AdaptiveResize( width => $IMAGE_X, height => $IMAGE_Y, filter => 'Cubic' );
$image->Extent( geometry => $GEOMETRY );
print "Values extrapolated\n";
print "Colors: ", $image->Get('colors'), "\n";
$x = $image->Write('x.gif');

print "Creating map\n";
open MAP, "<spmap999.src" or die "Can't open input map! $!";
binmode MAP;
open MAPOUT, ">spmap999.dat" or die "Can't open output map! $!";
binmode MAPOUT;

$/ = 
read(MAP, my $buffer, 70726, 0);
print MAPOUT $buffer;

my $odd = .5; 
for ($x = 1; $x < 159; $x++) {
    for ($y = 1; $y < 199; $y++) {
	$h = $image->GetPixel(x=>int (($x + $odd)/160*$IMAGE_X), y=>int ($y/200*$IMAGE_Y*0.866025404+13.263485025));
	$odd = .5 - $odd;
        my $c = $h * ($max-$min);
        if ($c < 0) {
# WATER HEX
        }
        $c -= $force_min;
        $c=0 if ($c < 0);
	{
		use integer;
		$c = $c / 10;
	}
	$c = $c > 15 ? 150 : 10*$c;
        my $b = pack 'C', $c;
        print MAPOUT $b;
	seek(MAP, 1, 1);
        read(MAP, my $buffer, 3, 0);
        print MAPOUT $buffer;
    }
#	print "\n";

    read(MAP, my $buffer, 16, 0);
    print MAPOUT $buffer;
}

while (!eof(MAP)) {
  read (MAP, my $buffer, 1024, 0);
  print MAPOUT $buffer;
}
