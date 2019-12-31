package libLSI::Configuration;

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

use boolean;
use File::Slurper 'read_text';
use FindBin;
use JSON;

use libLSI::Constants;

our $VERSION = $libLSI::Constants::VERSION;

sub new ($class) {
    my $self = {};
    bless $self, $class;

    return $self;
}

our sub get ($self) {
    my $file;
    if (-f "$FindBin::Bin/../configuration.json") {
        $file = "$FindBin::Bin/../configuration.json";

        my $content = read_text($file);
        my $config = decode_json($content);

        return $config;
    } else {
        return undef;
    }
}

true;