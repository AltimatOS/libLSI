#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(:5.30);
# Add features to system for lexical subs and signatures
# disable all warnings for these as they are still experimental
# (likely won't change much though in the future...)
no warnings "experimental::lexical_subs";
no warnings "experimental::signatures";
use feature 'lexical_subs';
use feature 'signatures';
use English;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";

use boolean;
use Data::Dumper;

use libLSI::BlprntParser;
use libLSI::Errors;

my $bp_file   = $ARGV[0];
if (! defined $bp_file) {
    $ENV{'LSI_DEBUG'} = 1;
    libLSI::BlprntParser::dbgmsg("ERROR", $_errors{'EINVAL'}->{'msg'} . ": Exiting");
    exit $_errors{'EINVAL'}->{'code'};
}

libLSI::BlprntParser::dbgmsg("INFO", "Blueprint: $bp_file");

my $bp_parser = libLSI::BlprntParser->new();
my %bp = $bp_parser->process_blueprint_file($bp_file);
libLSI::BlprntParser::dbgmsg("TRACE", Dumper \%bp);