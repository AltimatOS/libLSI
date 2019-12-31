#!/usr/bin/env perl

use strict;
use warnings;
use English;
use utf8;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";

use libLSI::Configuration;
use libLSI::BlprntParser;

my $cfg = libLSI::Configuration->new();
$ENV{'LSI_DEBUG'} = 1;
libLSI::BlprntParser::dbgmsg("DEBUG", "Configuratiion: " . Dumper($cfg->get));
