# copyxattr_toexif.pl

## Synopsis
A Perl script to copy geotags stored in extended attributes to image EXIF

## Usage

`% copyxattr_toexif` will process image files (raw and JPG) in the current directory.

`% copyxattr_toexif *.jpg` will process the given list of files.

`% copyxattr_toexif -r` will just read the extended attributes and print out values for confirmation.

## Options

* `-r`, `--readonly`: simulate copying the tags but do not update the files.

* `-o`, `--overwrite`: overwrite existing tags.

* `-g`, `--geotag`: copy only the geotags, not any others

* `-d`, `--debug`: print extra information (in practice, it only prints out the results of a calls to `Data::Dumper` at the moment).

* `-q`,`--quiet`: suppress most text output.

* `-h`, `--help`: print a brief help message.

## Description

This script will look for a handful of specific extended attributes saved by the [Lyn](http://lynapp.com) image management application in the image EXIF information. Currently it will save geotags, the star rating, (as Rating), and the Finder colour (stored as Label).

If no files are given, `copyxattr_toexif` will examine each supported file type in the current directory and process each in turn. Existing geotags are not altered.

Note that the implementation is specific to my own rating system in which the star ratings from Lyn on the reverse scale for ACDSee (i.e., an image rated 5 stars on Lyn will have an ACDSee rating of 1). And not all Finder colours have equivalents in ACDSee.

### Elevation lookup

Lyn can only store longitude and latitude when geotagging: it doesn't know about elevation. Since I do a lot of hiking (and almost all of it in Canada), I'd really like to have that info stored as well. Therefore I make use of the Canadian government free elevation lookup service. Code exists to use the equivalent USGS service in the USA, but not for any other countries. Ideally, I should check which country the location is in before looking up the elevation.

## Notes

* Warning: This program **will** modify your files. Please make sure you have backups of your image files before running this code.

* Currently only looks for JPGs, Nikon `.NEF`, Sony `.ARW` and Canon `.CR2`  files.

* Error checking hasn't been exhaustively tested yet.

* Developed on macOS, and makes use of the Finder user tag that stores a colour. Should still work on other Unix systems that support extended attributes though as it only tries to read the attributes.

* I couldn't find any info about rate limits for the elevation lookup queries, but I imagine it's not something to be abused. The elevation will not be written if it's not defined.

## Rationale

I use [Lyn](http://lynapp.com) for viewing, rating, and occasionally geotagging images on my Mac and wanted a way to preserve that information so that ACDSee on the Windows machine can read it. Similarly, I plan to create a version that stores extended attributes for the star rating and Finder colour.

## Perl modules required:

The following Perl modules will probably need to be installed before using this script:

* `Data::Plist::BinaryReader`
* `File::ExtAttr`
* `Image::ExifTool`
* `JSON::Parse`

Others that should already be present are:
* `Cwd`
* `IO::File`
* `LWP::Simple`
* `Getopt::Long`
* `Data::Dumper`

## Useful links

* http://www.sno.phy.queensu.ca/~phil/exiftool/geotag.html
* http://lynapp.com
* https://www.nrcan.gc.ca/earth-sciences/geography/topographic-information/free-data-geogratis/geogratis-web-services/api/17328
* https://nationalmap.gov/epqs/

## License and copyright

This software is licensed under GPL-3.0+.

Copyright &copy; 2017 Andy Gibb
