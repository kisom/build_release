#!/usr/bin/env perl

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
my $xbase = 0;          # include X11 sets
my $comp = 0;           # include compiler sets
my $games = 0;          # include game set
my $build = '';         # the build dir
my $mirror = "ftp://ftp.openbsd.org" ;
my $local_sets_path = '';
my $retcode = 0;
my $buildplatform = `uname -s`;
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
    $arch = '';
    $release = '';
}


# options
#   -a <arch>   set architecture
#   -r <rel>    set release
#   -s <site>   siteXX.tgz path
#   -g          include gamesXX.tgz
#   -x          include X11 sets
#   -c          include compiler sets
#
getopt('a:r:s:m:', \%opts);   

while ( my ($key, $value) = each(%opts) ) {
    if ("a" eq $key) {
        $arch = $value;
    }

    if ("r" eq $key) {
        $release = $value;
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

    if ("m" eq $key) {
        $mirror = "ftp://$value";
    }

}

if (("" eq $release) || ("" eq $arch)) {
    die "invalid arch $arch or release $release!" ;
}
else {
    print "building install iso for OpenBSD-$release/$arch\n";
}

if (scalar @ARGV == 2) {
    $site = $ARGV[0];
    $build = $ARGV[1];
}
else {
    die "need to specify the site file and the build dir!\n";
}

$local_sets_path = "$build/$release/$arch";
$mirror = "$mirror/pub/OpenBSD/$release/$arch";


if (!$site) {
    $site = "./site$release";
    $site =~ s/[.]// ;
    $site = $site . '.tgz';
}

else {
    my $matchsite = "site$release" ;
    $matchsite =~ s/[.]//;
    $matchsite = "$matchsite.tgz";
    print "$matchsite\n";
    if (!($site =~ /^[\/.\w\s]$matchsite/)) {
        die "invalid site file!";
    }
}

$retcode = system("mkdir -p $local_sets_path");
if ($retcode != 0) {
    die "could not create $local_sets_path!" ;
}

$retcode = system("wget --passive-ftp --reject \"*iso\" $mirror/*");
if (0 != $retcode) {
    die "could not fetch release file!";
}
