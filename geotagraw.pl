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

my ($QUIET, $DEBUG, $HELP, $NOSUBDIRS, $READONLY);
my $files;
my @FILES;
my $status = GetOptions("debug" => \$DEBUG,
			"files=s" => \$files,
			"nosubdirs" => \$NOSUBDIRS,
			"quiet"  => \$QUIET,
			"readonly" => \$READONLY,
			"help" => \$HELP);

if ($HELP) {
  print "geotagraw.pl: copy geotags from JPG EXIF into corresponding RAW files\n";
  print "Options:\n";
  print "  -r: readonly, determine which files have geotags and produce an output file\n".
    "      with names\n";
  print "  -f <filelist.txt>: name of file with list of names to copy geotags from/to\n";
  print "  -n: no-subdirs, only run in the current directory rather than traversing\n"
    ."     subdirectories\n";
  print "  -q: quiet, don't print any messages to screen\n";
  exit;
}

# Make it so...
if ($files) {
  print "Reading list of files to process from $files\n";
  $READONLY = 0;
  read_raw_file_list($files);
} else {
  process_current_directory();
  write_raw_file_list(@FILES);
}

############################
sub process_current_directory {
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
        process_current_directory();
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
      my $jpgfile = find_jpg_version($rawfile);
      if ($jpgfile) {
        print "  $rawfile: found $jpgfile" unless $QUIET;
        copy_geotags($jpgfile, $rawfile);
#      } else {
#        print "  $rawfile: has no corresponding jpg\n" unless $QUIET;
      }
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

  my $jpg_exif = Image::ExifTool->new();
  my $jpg_geotags = $jpg_exif->ImageInfo($jpg, 'gps:*');
  return if check_gpstag_error($jpg_exif, $jpg);

  my $raw_exif = Image::ExifTool->new();
  my $raw_geotags = $raw_exif->ImageInfo($raw, 'gps:*');
  return if check_gpstag_error($raw_exif, $raw);

  if ($jpg_geotags && keys %$jpg_geotags > 1) {
    print "\n";
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
          print "    $gpstag set to " . $jpg_geotags->{$gpstag} . "\n" unless $QUIET;
          $write_tag++;
        } else {
          print "    Something went wrong setting $gpstag: " . $err ."\n" unless $QUIET;
          $tag_errors++;
        }
      } else {
        print "    No need to update existing entry for $gpstag for ".basename($raw)."\n" unless $QUIET;
      }
    }
    $write_tag = 0 if ($tag_errors || $READONLY);
    if ($write_tag) {
      print "    -> updating $write_tag ".($write_tag == 1 ? "tag" : "tags")."\n" unless $QUIET;
      $raw_exif->WriteInfo($raw);
    }
    if ($READONLY) {
      push(@FILES, cwd().",$raw,$jpg\n");
    }
  } else {
    print ", but it has no GPS tags\n" unless $QUIET;
  }
}

sub check_gpstag_error {
  my ($exif, $file) = @_;
  if ($exif->GetValue('Error')) {
    print $exif->GetValue('Error') ." - $file\n";
    return 1;
  }
  return 0;
}

sub write_raw_file_list {
  my @file_list = @_;
  my $cwd = cwd();
  my $raw_file_list = File::Spec->catfile($cwd, basename($cwd)."_geotagraw.lis");
  open my $OFH, ">", $raw_file_list or die "Unable to open output file, $raw_file_list: $!\n";
  print $OFH @file_list;
}

sub read_raw_file_list {
  my $cwd = cwd();
  my $file_list = File::Spec->catfile($cwd, shift);
  if (-e $file_list) {
    open my $FH, "<", $file_list or die "Unable to open $file_list: $!\n";
    my @files = <$FH>;
    foreach my $entry (@files) {
      chomp($entry);
      my ($wd, $raw, $jpg) = split(/,/, $entry);
      copy_geotags(File::Spec->catfile($wd, $jpg), File::Spec->catfile($wd, $raw));
    }
  } else {
    print "Error - given file, $file_list, does not exist\n";
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
