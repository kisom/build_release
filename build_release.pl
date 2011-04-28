#!/usr/bin/env perl
# build_release.pl - build an OpenBSD release
# originally written by Kyle Isom <coder@kyleisom.net>
# 
# public domain / ISC dual-licensed - see LICENSE.

use warnings;
use strict;
use Getopt::Std;


#############
# VARIABLES #
#############
my %opts = ( );         # hash to collect options in

my $arch = '';          # arch to build release on
my $release = '';       # stores OpenBSD release 
my $site = '';
my $man = '';           # include the man pages
my $xbase = 0;          # include X11 sets
my $comp = 0;           # include compiler sets
my $games = 0;          # include game set
my $build = '';         # the build dir
my $mirror = "ftp://ftp.openbsd.org" ;
my $local_sets_path = '';
my $retcode = 0;
my $buildplatform = `uname -s`;
my $build_sets = 0;     # whether to build siteXX from
                        # staging dir
my $sets_path = "";
my $iso = "";           # output file
my $fetch = 1;          # fetch files via ftp
my $no_custom = 0;      # do not include a custom site file
chomp($buildplatform);


# get the current arch if on OpenBSD
if ('OpenBSD' eq $buildplatform) {
    # get current arch and release to use as the default
    $arch = `uname -m`;
    $release = `uname -r`; 
    chomp($arch);
    chomp($release);
}
else {
    # if not on OpenSBD, it's harder to pick a default
    # arch and release
    $arch = '';
    $release = '';
}


# options
#   -a <arch>   set architecture
#   -r <rel>    set release
#   -s <path>   build siteXX.tgz from <path>         
#   -s none     do not add in a site file
#   -m          include man pages
#   -g          include gamesXX.tgz
#   -x          include X11 sets
#   -c          include compiler sets
#   -m          set the FTP mirror
#   -o <path>   iso output directory         
#   -n          do not fetch files
#   -v          use a vanilla build (no siteXX)
#
getopt('a:r:s:f:o:mngxc', \%opts);   

# parse options and set relevant vars
while ( my ($key, $value) = each(%opts) ) {
    print "key: $key\tvalue: $value\n";
    if ("a" eq $key) {
        $arch = $value;
    }

    if ("r" eq $key) {
        $release = $value;
    }

    if ("m" eq $key) {
        $man = 1;
    }

    if ("g" eq $key) {
        $games = 1;
    }

    if ("x" eq $key) {
        $xbase = 1;
    }

    if ("c" eq $key) {
        $comp = 1;
    }

    if ("f" eq $key) {
        $mirror = "ftp://$value";
    }

    if ("s" eq $key) {
        $sets_path = $value;
    }

    if ("o" eq $key) {
        $iso = $value;
    }

    if ("n" eq $key) {
        $fetch = 0;
    }

    if ("v" eq $key) {
        $no_custom = 1;
    }

}

# can't build without a release or arch
if (("" eq $release) || ("" eq $arch)) {
    die "invalid arch $arch or release $release" ;
}
# check to make sure the tools needed are present
elsif (system("which mkisofs 2>&1 > /dev/null")) {
    die "cdrtools doesn't appear to be installed";
}
elsif (system("which wget 2>&1 > /dev/null")) {
    die "wget doesn't appear to be installed";
}
else {
    print "building install iso for OpenBSD-$release/$arch\n";
}

# set paths for build
if (scalar @ARGV == 2) {
    $site = $ARGV[0];
    $build = $ARGV[1];
}
elsif ((scalar @ARGV == 1) and ($build_sets)) {
    $build = $ARGV[0];
}

elsif ((scalar @ARGV == 1) and ($no_custom)) {
    $build = $ARGV[0];
}

else {
    die "need to specify the site file and the build dir";
}

$local_sets_path = "$build/$release/$arch";
$mirror = "$mirror/pub/OpenBSD/$release/$arch";

if (!$iso) {
    $iso = "$build/release$release.iso";
    $iso =~ s/[.]// ;
}

if (! -d $local_sets_path) {
    $retcode = system("mkdir -p $local_sets_path");
    if ($retcode != 0) {
        die "could not create $local_sets_path" ;
    }
}

if ((! $build_sets) and (! $no_custom)) {
    my $matchsite = "site$release" ;
    $matchsite =~ s/[.]//;
    $matchsite = "$matchsite.tgz";
    if (!($site =~ /^[\/.\w\s]*$matchsite/)) {
        die "invalid site file $site";
    }
    else {
        $retcode = system("cp $site $local_sets_path");
        if ($retcode) {
            die "could not copy $site to $local_sets_path";
        }
    }
}
elsif (! $no_custom) {
    $site = "site$release";
    $site =~ s/[.]// ;
    $site = $site . '.tgz';

    if (-d $sets_path) {
        if (!chdir($sets_path)) {
            die "could not chdir to $sets_path";
        }    
        $retcode = system("tar czf $local_sets_path/$site *");
        if ($retcode) {
            die "tarfile failed";
        }
    }
    else {
        die "invalid local sets path $sets_path";
    }
}

if (-e -z $site) {
    die "empty / invalid $site";
}

if (!(chdir $local_sets_path)) {
    die "could not chdir to $local_sets_path";
}

if ($fetch) {
    print "fetching sets...\n";
    $retcode = system("wget --passive-ftp --reject \"*iso\" " .
                      "--reject \"floppy*\" $mirror/*");
    if (0 != $retcode) {
        die "could not fetch release file";
    }
}

my $short_rel = "$release" ;
$short_rel =~ s/[.]// ;

if (!$man and -s "man$short_rel.tgz") {
    if (!unlink("man$short_rel.tgz")) { 
        die "could not remove man page set: $!";
    }
}

if (!$comp and -s "comp$short_rel.tgz") {
    if (!unlink("comp$short_rel.tgz")) {
        die "could not remove compiler set: $!";
    }
}

$retcode = system("ls x* 2> /dev/null");
if (!$xbase and !$retcode) {
    if (system("rm x*")) {
        die "could not remove X11 sets";
    }
}

if (!$games and -e -s "games$short_rel.tgz") {
    if (!unlink("games$short_rel.tgz")) {
        die "could not remove game set";
    }
}

# remove floppy boot images
$retcode = system("ls $local_sets_path/floppy*");
if (!$retcode and (! (unlink "floppy*"))) {
    die "could not remove floppy boot images!"
}

if (! (chdir $build)) {
    die "could not chdir to build root!";
}

my $mkisofs = " mkisofs -r -no-emul-boot -b $release/$arch/cdbr ";
$mkisofs = "$mkisofs -c boot.catalog -o $iso $build";

$retcode = system($mkisofs);
if ($retcode) {
    die "mkisofs failed";
}
else {
    print "\n\n\ncreated $iso\n";
}

