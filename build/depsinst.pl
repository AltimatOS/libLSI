#!/usr/bin/env perl

use strict;
use warnings;
use English;
use utf8;

my @deps = (
    'JSON',
    'Test::Pod',
    'Test::Pod::Coverage',
    'Test::Warnings',
    'Test::Spelling',
    'Test::Version',
    'Pod::Coverage::TrustPod',
    'ExtUtils::Config',
    'ExtUtils::Helpers',
    'ExtUtils::InstallPaths',
    'Readonly',
    'Perl::Critic',
    'Test::MinimumVersion',
    'Test::CPAN::Changes',
    'Test::CPAN::Meta',
    'Test::Mojibake',
    'Test::Portability::Files',
    'URI',
    'boolean',
    'List::MoreUtils',
    'Path::Tiny',
    'File::Slurper'
);

foreach my $dir (
    "/__w/libLSI/.cpan",
    "/__w/libLSI/.cpan/build",
    "/__w/libLSI/.cpan/prefs",
    "/__w/libLSI/.cpan/sources") {
    if (! -d $dir) {
        print STDOUT "Creating directory: $dir\n";
        mkdir($dir, 0755);
    } else {
        print STDOUT "Directory '$dir' already exists\n";
    }
}

foreach my $pkg (@deps) {
    print STDOUT "BUILDING: $pkg\n";
    system("/usr/local/bin/cpan -j /__w/libLSI/libLSI/build/MyConfig.pm -T $pkg");
    my $ret = $?;
    if ($ret != 0) {
        exit $ret;
    }
}

exit 0;
