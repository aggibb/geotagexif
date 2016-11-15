# geotagraw.pl

## Synopsis
A Perl script to copy geotags from JPGs to the corresponding raw file.

## Usage

`% geotagraw` will process files in the current and all subdirectories.

`% geotagraw --nosubdirs` will only process files in the current directory.

## Options

* `-n`, `--nosubdirs`: do not process any subdirectories.

* `-r`, `--readonly`: simulate copying the tags but do not update the raw file.

* `-d`, `--debug`: print extra information (in practice, it only prints out the results of a calls to `Data::Dumper` at the moment).

* `-q`,`--quiet`: suppress most text output.

## Description

The script looks for files with known raw format extensions and then in turn checks for correspondingly named JPGs. The `Image::ExifTool` module is used to read and copy all tags in the `gps` namespace from the JPG to the corresponding raw file.

`geotagraw` will look for an equivalently named JPG first: e.g., for a file called `DSC05124.ARW` it will look for `DSC05124.JPG` first. Failing that, it will pick the first JPG that matches the filename. For example, I use DxO Optics Pro and processed JPGs have `_DxO9` appended to the filename. The script will look for those JPGs too and will check the first one it finds for geotags. (Of course, if that file does not contain any geotags but others do, then the program will never know about them.)

The JPG geotags are taken as truth: if `geotagraw` finds existing geotags in the raw file, they will be compared with those in the JPG and if different, will be replaced.

By default, the script processes all subdirectories recursively, so be careful with the contents of those directories if you don't want the geotags transferred. Use the `-n` or `--nosubdirs` option to prevent this behaviour.

## Notes

Warning: This program **will** modify your files. Please make sure you have backups of your raw files before running this code. Existing geotags in the raw file will be **overwritten** and you will not be able to get them back! But then you do have a backup, right?

Currently only looks for Nikon `.NEF`, Sony `.ARW` and Canon `.CR2`  files.

Error checking hasn't been tested yet.

## Rationale

Garmin Basecamp is great for viewing and editing my GPS tracks, and it's perfectly capable of using those tracks to geotag my photos. Alas, it only applies geotags to the JPGs, not the raw files...

## Useful reading:

I found the following webpages useful when writing `geotagraw`:
* http://www.sno.phy.queensu.ca/~phil/exiftool/geotag.html
* http://superuser.com/questions/377431/transfer-exif-gps-info-from-one-image-to-another
* http://photo.stackexchange.com/questions/72711/how-can-i-copy-custom-exif-fields-from-one-image-to-another-with-exiftool
* http://ninedegreesbelow.com/photography/exiftool-commands.html

## License and copyright

This software is licensed under GPL-3.0+.

Copyright &copy; 2016 Andy Gibb
