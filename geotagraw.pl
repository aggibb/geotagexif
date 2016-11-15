#! /usr/bin/env perl

# POD at end of file

use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Spec;
use Image::ExifTool;
use Data::Dumper;
use Getopt::Long;

my ($QUIET, $DEBUG, $NOSUBDIRS, $READONLY);
my $status = GetOptions("quiet"  => \$QUIET,
                        "debug" => \$DEBUG,
			"nosubdirs" => \$NOSUBDIRS,
		        "readonly" => \$READONLY);

# Make it so...
process_dirs();

############################
sub process_dirs {
  my $cwd = cwd();
  print "Processing directory ".basename($cwd).": ";
  opendir(my $DH, $cwd);
  process_raw_files(get_raw_files($DH));

  unless ($NOSUBDIRS) {
    rewinddir($DH);
    my @subdirs = grep {-d $_ && !/^\.{1,2}$/} readdir($DH);
    if (@subdirs) {
      my $nsubdirs = (@subdirs == 1) ? "1 subdirectory" : @subdirs." directories";
      print "  Found $nsubdirs to process...\n" unless $QUIET;
      print Dumper(\@subdirs) if $DEBUG;
      foreach my $subdir (@subdirs) {
	chdir(File::Spec->catdir($cwd, $subdir));
	process_dirs();
	chdir($cwd);
      }
    }
  }
}

sub get_raw_files {
  return map {$_} grep {/ARW$|NEF$|CR2$/i} readdir(shift);
}

sub process_raw_files {
  if (@_) {
    my $files = @_ == 1 ? "file" : "files";
    print "found ".@_." raw $files to process";
    print " - READONLY" if $READONLY;
    print "\n";
    print Dumper(\@_) if $DEBUG;
    foreach my $rawfile (@_) {
      print "  $rawfile: " unless $QUIET;
      my $jpgfile = find_jpg_version($rawfile);
      unless ($QUIET) {
	if ($jpgfile) {
	  print "found $jpgfile\n";
	} else {
	  print "has no corresponding jpg\n";
	}
      }
      copy_geotags($jpgfile, $rawfile) if ($jpgfile);
    }
  } else {
    print "no files to process\n";
  }
}

sub find_jpg_version {
  my $raw = shift;
  my $cwd = cwd();
  my ($rawname, $extension) = split(/\./, $raw);
  opendir(my $DH, $cwd);
  my @jpgs = map {$_} grep {/$rawname\S+jpg$/i} readdir($DH);
  print Dumper(\@jpgs) if $DEBUG;
  if (@jpgs) {
    foreach my $jpg (@jpgs) {
      return $jpg if ($jpg eq $rawname.".JPG");
    }
    return $jpgs[0];
  }
}

sub copy_geotags {
  my ($jpg, $raw) = @_;
  my $cwd = cwd();
  my $jpg_filename = File::Spec->catfile($cwd, $jpg);
  my $raw_filename = File::Spec->catfile($cwd, $raw);
  my $jpg_exif = Image::ExifTool->new();
  my $raw_exif = Image::ExifTool->new();
  my $jpg_geotags = $jpg_exif->ImageInfo($jpg_filename, 'gps:*');
  if ($jpg_exif->GetValue('Error')) {
    print $jpg_exif->GetValue('Error') ." - $jpg\n";
    return;
  }
  my $raw_geotags = $raw_exif->ImageInfo($raw_filename, 'gps:*');
  if ($raw_exif->GetValue('Error')) {
    print $raw_exif->GetValue('Error') ." - $raw\n";
    return;
  }

  if ($jpg_geotags && keys %$jpg_geotags > 1) {
    my $tag_errors = 0;
    my $write_tag = 0;
    foreach my $gpstag (keys %$jpg_geotags) {
      # Catch the cases where the JPG and raw files have been geotagged separately
      my $update_tag = ($raw_geotags->{$gpstag} &&
			$raw_geotags->{$gpstag} ne $jpg_geotags->{$gpstag}) ? 1 : 0;
      my $add_tag = ($raw_geotags->{$gpstag}) ? 0 : 1;
      if ($add_tag || $update_tag) {
	my ($success, $err) = $raw_exif->SetNewValue($gpstag, $jpg_geotags->{$gpstag});
	if ($success) {
	  print "    Setting $gpstag to " . $jpg_geotags->{$gpstag} . "\n" unless $QUIET;
	  $write_tag++;
	} else {
	  print "    Something went wrong setting $gpstag: " . $err ."\n" unless $QUIET;
	  $tag_errors++;
	}
      } else {
	print "    No need to update existing entry for $gpstag for $raw\n" unless $QUIET;
      }
    }
    $write_tag = 0 if ($tag_errors || $READONLY);
    if ($write_tag) {
      print "    -> updating $write_tag ".($write_tag == 1 ? "tag" : "tags")."\n" unless $QUIET;
      $raw_exif->WriteInfo($raw_filename);
    }
  } else {
    print "    No GPS tags in " . $jpg ."\n" unless $QUIET;
  }
}

########

=head1 NAME

geotagraw.pl - a Perl script for copying existing EXIF geotags from JPGs to corresponding raw files

=head1 DESCRIPTION

See README.md for more info.

=head1 AUTHOR

Andy Gibb <aggibb@gmail.com>

=head1 COPYRIGHT and LICENSE

Copyright 2016 Andy Gibb.
