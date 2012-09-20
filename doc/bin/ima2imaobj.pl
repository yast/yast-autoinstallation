#!/usr/bin/perl -w

########################################################################
#                                                                      #
# This script generates the imageobjects for all PNGs and EPS' to be   #
# referenced in the SGML-files later                                   #
#                                                                      #
# © 2000 Stefan Siegel <siegel@linux-mandrake.com>                     #
#                                                                      #
########################################################################        
use strict;
use POSIX;           # only use POSIX style
use File::Basename;  # package to parse filenames
use Getopt::Long;    # package to handle commandline parameters

umask 0022;
 
########################################################################
# initialize variables:
my $app = fileparse($0);
my $entities = "";
my $lang = "en";
my $version = "$app (Image list) 1.0.0    2000-05-09";
my $verbose = 0;
########################################################################
my $usage =<<END_OF_USAGE;
Usage:  $app --help --lang=<name> --verbose --version
 
Options: [defaults in brackets after descriptions]
 
Configuration:
  --help       - shows this text.
  --lang=LL    - language to be refferenced [LL=$lang].
  --verbose    - self explaining.
  --version    - shows version number and exits.
 
END_OF_USAGE
########################################################################

sub echo_success {
  if($verbose == 1){
    print "\033[300C\033[20D[  \033[1;32mOK\033[0;39m  ]\n";
  }
  1;
}
 
sub echo_failure {
  if($verbose == 1){
    print "\033[300C\033[20D[\033[1;31mFAILED\033[0;39m]\n";
  }
  1;
}

sub echo_passed {
  if($verbose == 1){
    print "\033[300C\033[20D[\033[1;33mPASSED\033[0;39m]\n";
  }
  1;
}

sub parse_command_line {
  my ($opt_help, $opt_lang, $opt_verbose, $opt_version);
  my $result = GetOptions(
               'help'        => \$opt_help,
               'lang=s'      => \$opt_lang,
	       'version'     => \$opt_version,
	       'verbose!'    => \$opt_verbose,
               );
  usage("-", "invalid parameters") if not $result;

  usage("-") if defined $opt_help;    # if use wants help ...
  $opt_help = "";                     # 

  die "$version\n" if defined $opt_version;

  $lang = $opt_lang if defined $opt_lang;
  $verbose  = $opt_verbose if defined $opt_verbose;
}

sub usage {
  my $podfile = shift;
  warn "$app: $podfile: @_\n" if @_;
  die $usage;
}

########################################################################
########################################################################
#
# Here we go:

parse_command_line();

# search PNG and EPS folder for uniq images so that they are 
# _ALL_ referenced ...
my @files = qx(bin/findImages.sh $lang);

chop @files;

while( <@files> ){
  if($verbose == 1){
    print "\tindexing `$_'\n";
  }
  my $name = $_;
  $name =~ s/_/-/g;
  $name =~ s/.eps/.pdf/g;
  my $entity = $name;
  my $format="EPS";
  if ($entity =~ s/.png//g) {
      $format="PNG";
  } else {
      $entity =~ s/.pdf//g;
  }
  
  if ($format eq 'PNG') {
  $entities .= "<!ENTITY $entity '
  <imageobject> 
    <imagedata fileref=\"img/".$entity.".png\"   revision=\"1\" format=\"".$format."\" align=\"center\"/>
  </imageobject>
  <imageobject> 
    <imagedata fileref=\"img/".$entity.".png\"  revision=\"1\" format=\"PNG\" align=\"center\"/>
  </imageobject>' >\n";
  }else{
  $entities .= "<!ENTITY $entity '
  <imageobject> 
    <imagedata fileref=\"img/".$entity.".png\"  revision=\"1\" format=\"PNG\" align=\"center\"/>
  </imageobject>
  <imageobject> 
    <imagedata fileref=\"img/".$entity.".png\"  revision=\"1\" format=\"PNG\" align=\"center\"/>
  </imageobject>' >\n";

  }
}

my $file = "images.ent";

open (FILE, "> $file") || 
  die "Cannot open `$file' for writing: $!\n";

print "writing `$file' ... ";
print FILE $entities;
close (FILE);
print "done\n";
