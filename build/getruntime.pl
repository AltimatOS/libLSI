#!/usr/bin/env perl

use strict;
use warnings;
use English;
use utf8;

use Cwd;
use User::pwent;

my $dir = getcwd();

my $pw = getpwuid($UID);

print STDOUT "CWD: $dir\n";

print STDOUT "USER: ". $pw->name;
print STDOUT "HOME: ". $pw->dir;

system("/usr/bin/env");
system("perl -V");
