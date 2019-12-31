package libLSI::LicenseValidation;

use strict;
use warnings;
use English;
use utf8;

use feature qw(:5.30);
# Add features to system for lexical subs and signatures
# disable all warnings for these as they are still experimental
# (likely won't change much though in the future...)
no warnings "experimental::lexical_subs";
no warnings "experimental::signatures";
use feature 'lexical_subs';
use feature 'signatures';

use boolean;
use Data::Dumper;
use File::Slurper 'read_text';
use FindBin;
use JSON;

sub new ($class) {
    my $self = {};
    bless $self, $class;

    return $self;
}

our sub validate ($self, $content_type, $short_license_name) {
    my $license_list;
    if (-f "$FindBin::Bin/../share/licensesdb/licenses.json") {
        $license_list = "$FindBin::Bin/../share/licensesdb/licenses.json";
    }
    my $content = read_text($license_list);
    my $licenses_struct = decode_json($content);

    # now see if the requested license is in our "acceptable" list
    if ($short_license_name ne 'Proprietary') {
        if ($content_type eq 'software') {
            if (exists $licenses_struct->{'F/OSS'}->{$short_license_name}) {
                return true;
            } else {
                return false;
            }
        } elsif ($content_type eq 'content') {
            if (exists $licenses_struct->{'FreeOrOpenSourceContent'}->{$short_license_name}) {
                return true;
            } else {
                return false;
            }
        } elsif ($content_type eq 'documentation') {
            if (exists $licenses_struct->{'FreeOrOpenDocumentation'}->{$short_license_name}) {
                return true;
            } else {
                return false;
            }
        } elsif ($content_type eq 'fonts') {
            if (exists $licenses_struct->{'FreeOrOpenSourceFonts'}->{$short_license_name}) {
                return true;
            } else {
                return false;
            }
        }
    } else {
        return 'Proprietary';
    }
}

true;