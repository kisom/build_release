#!/usr/bin/env perl

use warnings;
use strict;
use Getopt::Std;
use Cwd;


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
my $create_site = 0;    #
my $mirror = "ftp://ftp.openbsd.org" ;
my $local_sets_path = '';
my $retcode = 0;
my $buildplatform = `uname -s`;
my $build_sets = 0; 
my $sets_path = "";
my $iso = "";
my $fetch = 1;
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
#   -s <path>   build siteXX.tgz from <path>         
#   -m          include man pages
#   -g          include gamesXX.tgz
#   -x          include X11 sets
#   -c          include compiler sets
#   -m          set the FTP mirror
#   -o <path>   iso output directory         
#   -n          do not fetch files
#
getopt('a:r:s:f:o:mgxc', \%opts);   

while ( my ($key, $value) = each(%opts) ) {
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
        $build_sets = 1;
    }

    if ("o" eq $key) {
        $iso = $value;
    }

    if ("n" eq $key) {
        $fetch = 0;
    }

}

if (("" eq $release) || ("" eq $arch)) {
    die "invalid arch $arch or release $release" ;
}
else {
    print "building install iso for OpenBSD-$release/$arch\n";
}

if (scalar @ARGV == 2) {
    $site = $ARGV[0];
    $build = $ARGV[1];
}
elsif ((scalar @ARGV == 1) and ($build_sets)) {
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

if (!$build_sets) {
    my $matchsite = "site$release" ;
    $matchsite =~ s/[.]//;
    $matchsite = "$matchsite.tgz";
    if (!($site =~ /^[\/.\w\s]*$matchsite/)) {
        die "invalid site file $site";
    }
    else {
        $retcode = system("cp $site $local_sets_path");
        if (!$retcode) {
            die "could not copy $site to $local_sets_path";
        }
    }
}
elsif ($build_sets) {
    $site = "site$release";
    $site =~ s/[.]// ;
    $site = $site . '.tgz';

    if (-r -d $sets_path) {
        $retcode = system("tar czf $local_sets_path/$site $sets_path");
    }
    else {
        die "invalid local sets path $sets_path";
    }
}
else {
    die "invalid site file";
}

if (-e -z $site) {
    die "empty / invalid $site";
}

if (!(chdir $local_sets_path)) {
    die "could not chdir to $local_sets_path";
}

my $pwd = getcwd;
print "now in $pwd\n";

if ($fetch) {
    $retcode = system("wget --passive-ftp --reject \"*iso\" " .
                      "--reject \"floppy*\" $mirror/*");
    if (0 != $retcode) {
        die "could not fetch release file";
    }
}

my $short_rel = "$release" ;
$short_rel =~ s/[.]// ;

if (!$man and -s "$local_sets_path/man$short_rel.tgz") {
    if (!unlink("$local_sets_path/man$short_rel.tgz")) { 
        die "could not remove man page set: $!";
    }
}

if (!$comp and -s "$local_sets_path/comp$short_rel.tgz") {
    if (!unlink("$local_sets_path/comp$short_rel.tgz")) {
        die "could not remove compiler set";
    }
}

if (!$xbase) {
    if (!system("rm $local_sets_path/x*")) {
        die "could not remove X11 sets";
    }
}

if (!$games and -s "$local_sets_path/games$short_rel.tgz") {
    if (!unlink("$local_sets_path/games$short_rel.tgz")) {
        die "could not remove game set";
    }
}

# remove floppy boot images
if (! (unlink "floppy*")) {
    die "could not remove floppy boot images!"
}

if (! (chdir $build)) {
    die "could not chdir to build root!";
}

my $mkisofs = " mkisofs -r -no-emul-boot -b $release/$arch/cdbr ";
$mkisofs = "$mkisofs -c boot.catalog -o $iso $build";

$retcode = system($mkisofs);
if (!$retcode) {
    die "mkisofs failed";
}
else {
    print "\n\n\ncreated $iso\n";
}

