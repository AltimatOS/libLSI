use strict;
use warnings;

use libLSI::Configuration;

use Test::More;

plan tests => 1;

my $cfg = libLSI::Configuration->new();
my $cfg_struct = $cfg->get();

isnt($cfg_struct, undef, "Check that the configuration structure is returned");
