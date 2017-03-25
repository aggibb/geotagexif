# -*-perl-*-

use strict;
use warnings;
use Data::Dumper;

use Cwd;
use Data::Plist::BinaryReader;
use File::ExtAttr ':all';
use Getopt::Long;
use Image::ExifTool;
use IO::File;
use LWP::Simple;
use JSON::Parse 'parse_json';

# See copyxattr_toexif.md

my ($DEBUG, $HELP, $QUIET, $READONLY);
my $status = GetOptions("debug" => \$DEBUG,
			"help" => \$HELP,
			"quiet" => \$QUIET,
			"readonly" => \$READONLY
		       );

if ($HELP) {
  print "copyxattr_toexif.pl : store extended attribute info in EXIF\n";
  print "Options:\n";
  print "  -r: readonly pass, and print out the values to be stored\n";
  print "  -q: quiet, don't print any messages\n";
  print "  -d: debug mode, print out data structures at various points\n";
  exit;
}

my @FILES;
if (@ARGV) {
  @FILES = get_image_filenames(@ARGV);
} else {
  my $cwd = cwd();
  print "Looking for image files in $cwd...\n";
  opendir(my $DH, $cwd);
  @FILES = get_image_filenames(readdir($DH));
}
exit unless @FILES;
print " Processing " . @FILES . (@FILES == 1 ? " image\n" : " images\n");
print Dumper(\@FILES) if $DEBUG;

my $bpread = Data::Plist::BinaryReader->new;
foreach my $image (@FILES) {
  my $fh = new IO::File($image);
  my %tags;
  foreach my $fattr (listfattr($fh)) {
    if (getfattr($fh, $fattr) =~ /^bplist/) {
      my $current_tag = $bpread->open_string(getfattr($fh, $fattr))->data;
      if ($fattr =~ /LynGeoTag/) {
	$tags{Geo} = $current_tag;
      } elsif ($fattr =~ /ItemStarRating/) {
	$tags{Rating} = (6 - $current_tag);
      } elsif ($fattr =~ /ItemUserTags/ && @$current_tag > 0) {
	my @colour = split(/\s+/,$current_tag->[0]);
	$tags{Label} = $colour[0];
      }
    }
  }
  copy_tags($image, \%tags) if %tags;
}

# ###########
sub get_image_filenames {
  my @list = @_;
  if (ref($list[0]) eq 'ARRAY') {
    @list = @{$list[0]};
  }
  return  map {$_} grep {/JPG$|ARW$|NEF$|CR2$/i} @list;
}

sub copy_tags {
  my ($image, $tags) = @_;
  if ($READONLY) {
    print_tags(@_);
    return;
  }
  print "All tags: " . Dumper($tags) if $DEBUG;
  my %tags = %$tags;
  my $exif = Image::ExifTool->new();
  my $image_geotags = $exif->ImageInfo($image, 'gps:*');
  my $tag_errors = 0;
  my $write_tag = 0;
  if ($tags{Geo}) {
    if ($image_geotags && keys %$image_geotags > 1) {
      # Should do some work here to see if the tags are the same
      print "Image $image already geotagged\n";
    } else {
      my $geotags = $tags{Geo};
      # No existing tags so just copy
      my %geotags = ("GPSLatitude" => $geotags->{lat},
		     "GPSLongitude" => $geotags->{lng},
		     "GPSLongitudeRef" => "West",
		     "GPSLatitudeRef" => "North",
		     "GPSMapDatum" => "WGS 84");
      my $elevation = lookup_elevation($geotags);
      if ($elevation) {
	$geotags{"GPSAltitude"} = $elevation;
	$geotags{"GPSAltitudeRef"} = "Above Sea Level";
      }
      my ($num_tags, $errors) = set_exif_tags($exif, %geotags);
      $write_tag += $num_tags;
      $tag_errors += $errors;
    }
  }
  delete $tags{Geo};
  # Now write other tags if present
  print "Non-geo tags: " . Dumper(\%tags) if $DEBUG;
  my ($num_tags, $errors) = set_exif_tags($exif, %tags);
  $write_tag += $num_tags;
  $tag_errors += $errors;
  
  my $success = 0;
  $write_tag = 0 if ($tag_errors || $READONLY);
  if ($write_tag) {
    print "Updating $write_tag ".($write_tag == 1 ? "tag" : "tags")." for $image\n"
	unless $QUIET;
    $exif->WriteInfo($image);
    $success = 1;
  }
  print $success ? "Success!\n" : "Hmm, didn't work\n" if ($write_tag && $DEBUG);
  return $success;
}

sub set_exif_tags {
  my ($exif, %tags) = @_;
  my ($write_tag, $tag_errors) = (0,0);
  foreach my $k (keys %tags) {
    my ($success, $err) = $exif->SetNewValue($k, $tags{$k});
    if ($success) {
      $write_tag++;
    } else {
      print "Error setting $tags{$k}: " .$err ."\n";
      $tag_errors++;
    }
  }
  return ($write_tag, $tag_errors)
}

sub lookup_elevation_usgs {
  my $geotags = shift;
  my $url = "https://nationalmap.gov/epqs/pqs.php?x=".$geotags->{lng}
    ."&y=".$geotags->{lat}."&units=Meters&output=json";
  my $request_contents = get($url);
  print Dumper($request_contents) if $DEBUG;
  if ($request_contents) {
    my $data = parse_json($request_contents);
    return $data->{USGS_Elevation_Point_Query_Service}->{Elevation_Query}->{Elevation};
  } else {
    print "USGS Elevation lookup service is not available at this time\n";
    return;
  }
}

sub lookup_elevation {
  # Canadian gov GeoGratis service provides elevation estimate to nearest integer
  my $geotags = shift;
  my $url = "http://geogratis.gc.ca/services/elevation/cdem/altitude?lat=".$geotags->{lat}
    ."&lon=".$geotags->{lng};
  my $request_contents = get($url);
  print Dumper($request_contents) if $DEBUG;
  if ($request_contents) {
    my $data = parse_json($request_contents);
    return $data->{altitude};
  } else {
    print "GeoGratis Elevation API is not available at this time\n";
    return;
  }
}

sub print_tags {
  my ($image, $tags) = @_;
  if ($tags->{Geo}) {
    my $geotags = $tags->{Geo};
    print "Geotag attributes for $image:\n  Latitude = ".$geotags->{lat}.
	"\n  Longitude = ".$geotags->{lng}."\n";
    print "  Elevation = ".lookup_elevation($geotags)." (GeoGratis lookup)\n";
  }
  print "ACDSee tags:\n";
  print "  Label = ".$tags->{Label}."\n" if ($tags->{Label});
  print "  Rating = ".$tags->{Rating}."\n" if ($tags->{Rating});
}
