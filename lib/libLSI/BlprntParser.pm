package libLSI::BlprntParser;

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
no warnings "experimental::smartmatch";
use feature 'lexical_subs';
use feature 'signatures';

use MIME::Base64;
use boolean;
use Data::Dumper;
use File::Basename;
use List::MoreUtils qw(first_index);
use Path::Tiny;
use URI;

use libLSI::Constants;
use libLSI::Configuration;
use libLSI::Errors;
use libLSI::LicenseValidation;

=head1 NAME

libLSI::BlprntParser: Library code for the Linux Software Installer and package format

=head1 VERSION

Version: 0.0.1

=head1 AUTHOR

Gary L. Greene, Jr. C<< greeneg at altimatos.com >>

=cut

our $VERSION = $libLSI::Constants::VERSION;

my %keyword = (
    'blueprint' => 'Blueprint',
    'end'       => 'End'
);
my $cfg = libLSI::Configuration->new();
my $cfg_struct = $cfg->get();
if (! defined $cfg_struct) {
    dbgmsg("ERROR", $_errors{'ENOENT'}->{'msg'} . ": Exiting");
    exit $_errors{'ENOENT'}->{'code'};
}

=head1 SUBROUTINES/METHODS

=head2 METHOD: new

=head3 DESCRIPTION:

    Object constructor

=head3 SCOPE:

=over

=item Public

=back

=head3 ARGUMENT(S):

=over

=item SCALAR: class name

=back

=head3 RETURN VALUE(S):

=over

=item REFERENCE: Object hash as a scalar reference

=back

=cut
sub new ($class) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my $self = {};
    bless $self, $class;

    return $self;
}

=head2 SUBROUTINE: validate_msg_level

=head3 DESCRIPTION:

    Subroutine to validate that the value passed in is one of the known
    message levels, 

=over

=item INFO

=item DEBUG

=item TRACE

=item NOTICE

=item WARNING

=item ERROR

=item CRITICAL

=item ALERT

=item EMERGENCY

=back

    This is NOT an OO method, and does not take an object reference.

=head3 SCOPE:

=over

=item Public

=back

=head3 ARGUMENT(S):

=over

=item SCALAR: the message level to validate

=back

=head3 RETURN VALUE(S):

=over

=item SCALAR: boolean

    If the value passed in is a valid message level, it returns a scalar true
    value. Otherwise, false.

=cut
sub validate_msg_level ($level) {
    given (uc $level) {
        when ('INFO') { return true; }
        when ('DEBUG') { return true; }
        when ('TRACE') { return true; }
        when ('NOTICE') { return true; }
        when ('WARNING') { return true; }
        when ('ERROR') { return true; }
        when ('CRITICAL') { return true; }
        when ('ALERT') { return true; }
        when ('EMERGENCY') { return true; }
    };
    return false;
}

=head2 SUBROUTINE: dbgmsg

=head3 DESCRIPTION:

    Subroutine to print out debug information based off whether the 'LSI_DEBUG'
    environment variable is defined.

    This is NOT an OO method, and does not take an object reference.

=head3 SCOPE:

=over

=item Public

=back

=head3 ARGUMENT(S):

=over

=item SCALAR: The message string to output

=item SCALAR: The message class

   The level of the message to be emitted. These are based off the traditional
   syslog levels, with the addition of the TRACE level used for tracing code
   paths. These levels are:
   
=over

=item INFO

=item DEBUG

=item TRACE

=item NOTICE

=item WARNING

=item ERROR

=item CRITICAL

=item ALERT

=item EMERGENCY

=back

=back

=head3 RETURN VALUE(S):

=over

=item VOID

=back

=cut
sub dbgmsg ($level, $msg) {
    if (validate_msg_level($level)) {
        $level = uc $level;
    } else {
        dbgmsg("ERROR", $_errors{'EINVAL'}->{'msg'} . ": Exiting");
        exit $_errors{'EINVAL'}->{'code'};
    }

    my %level_by_int = (
        8 => 'TRACE',
        7 => 'DEBUG',
        6 => 'INFO',
        5 => 'NOTICE',
        4 => 'WARNING',
        3 => 'ERROR',
        2 => 'CRITICAL',
        1 => 'ALERT',
        0 => 'EMERGENCY'
    );
    my %level_by_name = (
        'TRACE'     => 8,
        'DEBUG'     => 7,
        'INFO'      => 6,
        'NOTICE'    => 5,
        'WARNING'   => 4,
        'ERROR'     => 3,
        'CRITICAL'  => 2,
        'ALERT'     => 1,
        'EMERGENCY' => 0
    );

    if (defined $ENV{'LSI_DEBUG'}) {
        if ($ENV{'LSI_DEBUG'} <= $level_by_name{$level}) {
            say STDERR "$level: $msg";
        }
    }
}

=head2 METHOD: check_for_blueprint_block_bounding

=head3 DESCRIPTION:

    Method to validate whether the blueprint starts and ends with the correct keywords, 'Blueprint' and 'End'

=head3 SCOPE:

=over

=item Private

=back

=head3 ARGUMENT(S):

=over

=item SCALAR REFERENCE: Object reference

=item LIST: blueprint file contents

=back

=head3 RETURN VALUE(S):

=over

=item SCALAR: boolean

=back

=cut
our sub check_for_blueprint_block_bounding ($self, @contents) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    # trim leading and trailing whitespace...
    my $f_line = $contents[0];
    my $l_line = $contents[-1];

    dbgmsg("DEBUG", "first: $f_line");
    dbgmsg("DEBUG", "last: $l_line");
    dbgmsg("DEBUG", "Keyword blueprint: $keyword{blueprint}");
    dbgmsg("DEBUG", "Keyword blueprint: $keyword{end}");

    $f_line =~ s/^\s+|\s+$//g;
    $l_line =~ s/^\s+|\s+$//g;

    if ($f_line eq $keyword{blueprint} &&
        $l_line eq $keyword{end}) {
        return true;
    } else {
        return false;
    }
}

=head2 METHOD: parse_pkg_type

=head3 DESCRIPTION:

    Method to validate that the package type is a known type. If known, it
    returns the value of the 'pkgtype' metadata attribute. If the type is
    unknown, the method will emit an error string and exit the application.

=head3 SCOPE:

=over

=item Private

=back

=head3 ARGUMENT(S):

=over

=item SCALAR REFERENCE: Object reference

=item LIST: Blueprint file contents

=back

=head3 RETURN VALUE(S):

=over 2

=item SCALAR: the value from the pkgtype attribute

This is returned only if the package type is a known type:

=over 3

=item content

=item documentation

=item fonts

=item software

=back

    If not, the return value is an undef value

=item ARRAY REFERENCE: the updated working copy of the blueprint

=back

=cut
our sub parse_pkg_type ($self, @bp_wc_contents) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@bp_wc_contents) {
        $line =~ s/^\s+|\s+$//g;
        if ($line =~ m/^pkgtype:\s+(content|documentation|fonts|software)$/) {
            # remove found item from the array
            @bp_wc_contents = grep { $_ ne $line } @bp_wc_contents;
            $line =~ s/pkgtype:\s+//;
            return $line, \@bp_wc_contents;
        }
    }
    # otherwise...
    return undef, \@bp_wc_contents;
}

=head2 METHOD: is_capability_name
=cut
my sub is_capability_name ($self, $string) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    if ($string =~ m/^/) {}
}

our sub parse_srcpkg_name ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        # name takes a normal word value (no whitespace)
        if ($line =~ m/^name:\s+\w+$/) {
            dbgmsg("DEBUG", "Found blueprint 'name' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^name:\s+//;
            dbgmsg("DEBUG", "blueprint 'name' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub is_version_string ($self, $version_string) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    # versions can be of the following formats:
    #  - lone digit                             example: 1
    #  - major dot minor                        example: 1.0
    #  - major dot minor rev-letter             example: 1.0i
    #  - major dot minor dot patch              example: 5.3.6
    #  - major dot minor underscore tag         example: 0.1_pre1
    #  - series dot major dot minor dot patch   example: 6.1.100.1999
    if ($version_string =~ m/(\d+)((\.\d+)*)([a-z]?)((_(pre|p|beta|alpha|rc)\d*)*)/) {
        return true;
    }
    return false;
}

our sub parse_pkg_version ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^version:\s+.*$/) {
            dbgmsg("DEBUG", "Found blueprint 'version' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^version:\s+//;
            if (is_version_string($self, $line)) {
                dbgmsg("DEBUG", "blueprint 'version' value: $line");
                return $line;
            }
        }
    }
    return undef;
}

our sub parse_pkg_release ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\+s$//g;

        if ($line =~ m/^release:\s+\d+.*$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'release' keyword");
            $line =~ s/^release:\s+//;
            dbgmsg("DEBUG", "blueprint 'release' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub parse_pkg_distribution ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^distribution:\s+\w+$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'distribution' keyword");
            $line =~ s/^distribution:\s+//;
            dbgmsg("DEBUG", "blueprint 'distribution' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub parse_pkg_license ($self, $content_type, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^license:\s+([a-zA-Z0-9\.\_\-\+\(\)]+)$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'license' keyword");
            $line =~ s/license:\s+//;
            # test that this is a valid open source license. If not,
            #   set the taint flag
            my $lic_validator = libLSI::LicenseValidation->new();
            my ($valid, $class) = $lic_validator->validate($content_type, $line);
            if ($valid == true) {
                dbgmsg("DEBUG", "License Valitation for license $line: true");
                return $line, $class;
            } else {
                dbgmsg("DEBUG", "License Valitation for license $line: false");
                return undef, undef;
            }
        }
    }
    return undef, 0;
}

our sub parse_capabilities ($self, $string) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    return split(', ', $string);
}

our sub make_caps_struct ($self, @cap_list) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %cap_struct;
    foreach my $ent (@cap_list) {
        dbgmsg("DEBUG", "cap_list entry: $ent");
        if ($ent =~ m|^/[a-zA-Z\-\_/]+$|) {
            dbgmsg("DEBUG", "Capability type: file_path");
            $cap_struct{"$ent"} = { 'type' => 'file_path' };
        } elsif ($ent =~ m/^\w+$/) {
            dbgmsg("DEBUG", "Capability type: unpinned_pkg");
            $cap_struct{"$ent"} = { 'type' => 'unpinned_pkg' };
        } elsif ($ent =~ m|^(\w+\s+\>\<\=\!\s+.*)$|) {
            dbgmsg("DEBUG", "Capability type: pinned_pkg");
            my ($pkg_name, $cmp_expression, $version) = split(/\s+/, $ent);
            $cap_struct{"$pkg_name"} = { 'type' => 'pinned_pkg' };
            $cap_struct{"$pkg_name"} = { 'cmpexp' => "$cmp_expression" };
            $cap_struct{"$pkg_name"} = { 'version' => "$version" };
        }
    }
    return %cap_struct;
}

our sub parse_pkg_build_requires ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^buildrequires:\s+([\w+\,\s+]+)$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'buildrequires' keyword");
            $line =~ s/buildrequires:\s+//;
            # parse capabilities
            my @cap_list = parse_capabilities($self, $line);
            my %cap_struct = make_caps_struct($self, @cap_list);
            return \%cap_struct;
        }
    }
    return undef;
}

our sub parse_pkg_requires ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^requires:\s+([\w+\,\s+]+)$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'requires' keyword");
            $line =~ s/requires:\s+//;
            # parse capabilities
            my @cap_list = parse_capabilities($self, $line);
            my %cap_struct = make_caps_struct($self, @cap_list);
            return \%cap_struct;
        }
    }
    return undef;
}

our sub interpolate_variables ($self, $bp_struct, $line) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    # read in configuration JSON
    my $cfg = libLSI::Configuration->new();
    my $cfg_struct = $cfg->get();

    my $pkg_root = $cfg_struct->{'pkg_root'};
    my $tmp_dir = $cfg_struct->{'tmp_dir'};
    my $srcpkg_name = $bp_struct->{'srcpkg_name'};
    my $pkg_version = $bp_struct->{'version'};
    my $pkg_release = $bp_struct->{'release'};

    if ($line =~ m/\$NAME/) {
        $line =~ s/\$NAME/$srcpkg_name/g;
    }
    if ($line =~ m/\$VERSION/) {
        $line =~ s/\$VERSION/$pkg_version/g;
    }
    if ($line =~ m/\$RELEASE/) {
        $line =~ s/\$RELEASE/$pkg_release/;
    }
    if ($line =~ m/\$TMP_DIR|\$TMPDIR/) {
        $line =~ s/\$TMP_DIR|\$TMPDIR/$tmp_dir/;
    }
    if ($line =~ m/\$PKG_ROOT/) {
        $line =~ s/\$PKG_ROOT/$pkg_root/;
    }

    return $line;
}

our sub parse_pkg_buildroot ($self, $bp_struct, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^buildroot:\s+\$[a-zA-Z0-9]+\/[\$a-zA-Z0-9\-\_\/]+$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'buildroot' keyword");
            $line =~ s/buildroot:\s+//;
            # do substitutions
            $line = interpolate_variables($self, $bp_struct, $line);
            return $line;
        }
    }
    # if the build root isn't defined, force a sane default
    my $cfg = libLSI::Configuration->new();
    my $cfg_struct = $cfg->get();
    my $pkg_name = $bp_struct->{'srcpkg_name'};
    my $pkg_version = $bp_struct->{'version'};
    my $pkg_release = $bp_struct->{'release'};
    my $default_br = "$cfg_struct->{'tmp_dir'}/${pkg_name}-${pkg_version}-${pkg_release}-buildroot";
    $default_br = interpolate_variables($self, $bp_struct, $default_br);
    return $default_br;
}

our sub parse_pkg_url ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^url:\s+(http|https|ftp):\/\/[a-zA-Z0-9\.\-\_\?\/\&\;\=\:\,\{\}\[\]\'\"]+/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found blueprint 'url' keyword");
            $line =~ s/^url:\s+//;
            return $line;
        }
    }
    return undef;
}

our sub parse_source_chksum ($self, $src_position, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^chksum$src_position:\s+.*/) {
            dbgmsg("DEBUG", "Found blueprint 'chksum$src_position' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s|^chksum$src_position:\s+||;
            dbgmsg("DEBUG", "Value of chksum$src_position: $line");

            if ($line eq 'unavailable') {
                return undef;
            } else {
                return $line;
            }
        }
    }

    return undef;
}

our sub parse_source_signature ($self, $src_position, $bp_struct, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %signature;
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^signature$src_position:\s+.*/) {
            dbgmsg("DEBUG", "Found blueprint 'signature$src_position' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s|^signature$src_position:\s+||;
            $line = interpolate_variables($self, $bp_struct, $line);
            dbgmsg("DEBUG", "Value of 'signature$src_position': $line");
            my $file = undef;
            if ($line =~ m/^(http|https|ftp):\/\/.*/) {
                dbgmsg("DEBUG", "Contains URL for file location");
                my $url = URI->new($line);
                my $path = $url->path();
                $file = fileparse($path);
                $signature{'signature_file'} = $file;
                $signature{'url'} = $url->as_string;
            } else {
                $signature{'signature_file'} = $line;
                $signature{'url'} = undef;
            }
            return \%signature;
        }
    }

    return undef;
}

our sub parse_pkg_sources ($self, $bp_struct, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %sources;
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^(source(\d*)):\s+.*$/) {
            # if it exists, grab the numeric entry to use as a key record
            my $position = undef;
            if (defined $2) {
                dbgmsg("DEBUG", "Got positional of $2");
                $position = $2;
            } else {
                # there is only one source, so set to 0
                dbgmsg("DEBUG", "Found no positional. Set to 0");
                $position = 0;
            }
            dbgmsg("DEBUG", "Found blueprint 'source$position' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^source\d*:\s+//;
            $line = interpolate_variables($self, $bp_struct, $line);
            if ($line =~ m/^(http|https|ftp):\/\/.*/) {
                dbgmsg("DEBUG", "Contains URL to file");
                # is url, lets parse it
                my $url = URI->new($line);
                my $path = $url->path();
                my $file = fileparse($path);
                dbgmsg("DEBUG", "URL: $line");
                dbgmsg("DEBUG", "URL path: $path");
                dbgmsg("DEBUG", "Filename: $file");
                # now see if the blueprint contains a usable checksum and signature
                # for the sources
                my $checksum = parse_source_chksum($self, $position, $bp_wc);
                my $signature = parse_source_signature($self, $position, $bp_struct, $bp_wc);
                $sources{$position} = {
                    'file'      => $file,
                    'url'       => $line,
                    'chksum'    => $checksum,
                    'signature' => $signature
                };
            } else {
                dbgmsg("DEBUG", "Local source file");
                dbgmsg("DEBUG", "File: $line");
                my $checksum = parse_source_chksum($self, $position, $bp_wc);
                my $signature = parse_source_signature($self, $position, $bp_wc);
                $sources{$position} = {
                    'file'      => $line,
                    'url'       => undef,
                    'chksum'    => $checksum,
                    'signature' => $signature
                };
            }
            return \%sources;
        }
    }

    return undef;
}

our sub parse_pkg_require_root_build ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^root_required_for_build:\s+(true|false)/) {
            dbgmsg("DEBUG", "Found blueprint 'root_required_for_build' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^root_required_for_build:\s+//;
            return $line;
        }
    }

    return undef;
}

our sub parse_pkg_format ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^pkgformat:\s+(standard|meta|bundle)$/) {
            dbgmsg("DEBUG", "Found blueprint 'pkgformat' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^pkgformat:\s+//;
            dbgmsg("DEBUG", "blueprint 'pkgformat' value: $line");
            return $line;
        }
    }

    return undef;
}

our sub parse_pkg_upstream_maintainer ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^upstream_maintainer:\s+[\w\s\<\>\@\.]+/) {
            dbgmsg("DEBUG", "Found blueprint 'upstream_maintainer' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^upstream_maintainer:\s+//;
            dbgmsg("DEBUG", "blueprint 'upstream_maintainer' value: $line");
            return $line;
        }
    }

    return undef;
}

our sub parse_pkg_vendor ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^vendor:\s+[\w\s]+/) {
            dbgmsg("DEBUG", "Found blueprint 'vendor' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^vendor:\s+//;
            dbgmsg("DEBUG", "blueprint 'vendor' value: $line");
            return $line;
        }
    }

    return undef;
}

our sub parse_pkg_list ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^packages:\s+[a-zA-Z0-9\-\_\s\,]+/) {
            dbgmsg("DEBUG", "Found blueprint 'packages' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^packages:\s+//;
            my @packages = split(/\,\s+/ ,$line);
            dbgmsg("DEBUG", "blueprint 'packages' value: @packages");
            return \@packages;
        }
    }

    return undef;
}

my sub parse_bp_metadata ($self, $content_type, @bp_wc_contents) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %bp_struct = ();

    dbgmsg("DEBUG", "Content Type: $content_type");
    # first trim leading whitespace
    foreach my $line (@bp_wc_contents) {
        dbgmsg("DEBUG", "line: $line");
    }

    $bp_struct{'pkgtype'}       = $content_type;
    $bp_struct{'pkgformat'}     = parse_pkg_format($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'srcpkg_name'}   = parse_srcpkg_name($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'version'}       = parse_pkg_version($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'release'}       = parse_pkg_release($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'distribution'}  = parse_pkg_distribution($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    ($bp_struct{'license'},
     $bp_struct{'foss'}    )    = parse_pkg_license($self, $content_type, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'buildrequires'} = parse_pkg_build_requires($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'buildroot'}     = parse_pkg_buildroot($self, \%bp_struct, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'url'}           = parse_pkg_url($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'sources'}       = parse_pkg_sources($self, \%bp_struct, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'upstream_maintainer'}   = parse_pkg_upstream_maintainer($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'vendor'}        = parse_pkg_vendor($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'root_build'}    = parse_pkg_require_root_build($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'package_list'}      = parse_pkg_list($self, \@bp_wc_contents);
    dbgmsg("DEBUG", "BP lines: ". scalar @bp_wc_contents);

    return \@bp_wc_contents, %bp_struct;
}

our sub parse_pkg_tags($self, $line) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    $line =~ s/^tags:\s+//;

    return split(', ', $line);
}

our sub extract_pkg_info ($self, $pkg_name, $bp_struct, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %bp_struct = %{$bp_struct};
    my $pkgname = undef;
    my $start_num = undef;
    my $end_num = undef;
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^Package\s+$pkg_name$/) {
            $start_num = first_index { $_ eq $line } @{$bp_wc};
            dbgmsg("DEBUG", "Found package: $pkg_name");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            my @pkg = ();
            foreach my $_line (@{$bp_wc}) {
                # get the line number we're on...
                $end_num = first_index { $_ eq $_line } @{$bp_wc};
                last if ($_line =~ m/^\s+End$/);
                push(@pkg, $_line);
            }
            return $start_num, $end_num, @pkg;
        }
    }

}

our sub parse_pkg_description ($self, @pkg_info) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my $description = undef;
    my @pkg_wc = @pkg_info;
    my @raw_description = ();

    my $end_num = undef;
    foreach my $line (@pkg_wc) {
        if ($line =~ m/^\s*Description\s*$/) {
            @pkg_wc = grep { $_ ne $line } @pkg_wc;
            dbgmsg("DEBUG", "Found package description block");
            foreach my $_line (@pkg_info) {
                dbgmsg("DEBUG", "\$_line: $_line");
                $end_num = first_index { $_ eq $_line } @pkg_info;
                last if ($_line =~ m/^\s+EndDescription\s*$/);
                $_line =~ s/^\s+|\s+$//g;
                push(@raw_description, $_line) if $_line !~ m/^\s*Description\s*$/;
            }
        }
    }

    @pkg_info = @pkg_info[ (${end_num} + 1) .. $#pkg_info];
    $description = "@raw_description";
    $description = encode_base64($description);

    # remove the description block from the working copy


    return $description, @pkg_info;
}

our sub extract_code_block ($self, $block_name, @content) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my $end_num = undef;
    my @block = ();

    foreach my $line (@content) {
        if ($line =~ m/^\s*$block_name\s*$/) {
            dbgmsg("DEBUG", "Found package post-install block");
            foreach my $_line (@content) {
                dbgmsg("DEBUG", "\$_line: $_line");
                $end_num = first_index { $_ eq $_line } @content;
                last if ($_line =~ m/^\s*End$block_name\s*$/);
                $_line = encode_base64($_line) if $_line !~ m/^\s*$block_name\s*$/;
                chomp $_line;
                push(@block, $_line) if $_line !~ m/^\s*$block_name\s*$/;
            }
        }
    }

    @content = @content[ (${end_num} + 1) .. $#content];

    return \@block, @content;
}

our sub parse_bp_pkgs ($self, $pkg_name, $bp_struct, @pkg_info) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my @pkg_wc = @pkg_info;

    my %bp_struct = %{$bp_struct};
    $bp_struct{'packages'}->{$pkg_name} = ();
    foreach my $line (@pkg_wc) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ /^summary:\s+.*/) {
            dbgmsg("DEBUG", "Found package keyword 'summary'");
            @pkg_info = grep { $_ !~ m/^\s*summary:\s+.*$/ } @pkg_info;
            $line =~ s/^summary:\s+//;
            $bp_struct{'packages'}->{$pkg_name}->{'summary'} = $line;
        } elsif ($line =~ /^group:\s+/) {
            dbgmsg("DEBUG", "Found package keyword 'group'");
            @pkg_info = grep { $_ !~ m/^\s*group:\s+.*$/ } @pkg_info;
            $line =~ s/^group:\s+//;
            $bp_struct{'packages'}->{$pkg_name}->{'group'} = $line;
        } elsif ($line =~ m/^tags:\s+/) {
            dbgmsg("DEBUG", "Found package keyword 'tags'");
            @pkg_info = grep { $_ !~ m/^\s*tags:\s+.*$/ } @pkg_info;
            $line =~ s/^tags:\s+//;
            # each tag is delimited by a comma, so put that in a list
            my @tags = split(/\,\s+|\,/, $line);
            # there can be only one tag set in a package, so we can safely
            #   put the whole list onto the structure
            $bp_struct{'packages'}->{$pkg_name}->{'tags'} = \@tags;
        } elsif ($line =~ m/^requires:\s+/) {
            dbgmsg("DEBUG", "Found package keyword 'requires'");
            @pkg_info = grep { $_ !~ m/^\s*requires:\s+.*$/ } @pkg_info;
            $line =~ s/^requires:\s+//;
            # split on any commas
            my @requires = split(/\,\s+|\,/, $line);
            if (! exists($bp_struct{'packages'}->{$pkg_name}->{'requires'})) {
                $bp_struct{'packages'}->{$pkg_name}->{'requires'} = \@requires;
            } else {
                my $type = ref $bp_struct{'packages'}->{$pkg_name}->{'requires'};
                if ($type == 'ARRAY') {
                    # extract that array and push the requires list to the end
                    my @_requires = @{$bp_struct{'packages'}->{$pkg_name}->{'requires'}};
                    push(@requires, @_requires);
                    $bp_struct{'packages'}->{$pkg_name}->{'requires'} = \@requires;
                }
            }
        } elsif ($line =~ m/^provides:\s+/) {
            dbgmsg("DEBUG", "Found package keyword 'provides'");
            @pkg_info = grep { $_ !~ m/^\s*provides:\s+.*$/ } @pkg_info;
            $line =~ s/^provides:\s+//;
            my @provides = split(/\,\s+|\,/, $line);
            if (! exists($bp_struct{'packages'}->{$pkg_name}->{'provides'})) {
                $bp_struct{'packages'}->{$pkg_name}->{'provides'} = \@provides;
            } else {
                my $type = ref $bp_struct{'packages'}->{$pkg_name}->{'provides'};
                if ($type == 'ARRAY') {
                    my @_provides = @{$bp_struct{'packages'}->{$pkg_name}->{'provides'}};
                    push(@provides, @_provides);
                    $bp_struct{'packages'}->{$pkg_name}->{'provides'} = \@provides;
                }
            }
        } elsif ($line =~ m/^pkgclass:\s+/) {
            dbgmsg("DEBUG", "Found package keyword 'pkgclass'");
            @pkg_info = grep { $_ !~ m/^\s*pkgclass:\s+.*$/ } @pkg_info;
            $line =~ s/^pkgclass:\s+//;
            $bp_struct{'packages'}->{$pkg_name}->{'pkgclass'} = $line;
        } elsif ($line =~ m/^Description/) {
            dbgmsg("DEBUG", "Found package keyword 'Description' block");
            my $description = undef;
            ($description, @pkg_info) = parse_pkg_description($self, @pkg_info);
            chomp($description);
            $bp_struct{'packages'}->{$pkg_name}->{'description'} = $description;
        } elsif ($line =~ m/^Trigger\s+[a-zA-Z0-9\-\_\+\.]+/) {
            dbgmsg("DEBUG", "Found package keyword 'Trigger' block");
            # TODO: Rework, since right now, this only allows one trigger block to exist in
            # a package, which might not necessarily be appropriate
            my $trigger_block = undef;
            ($trigger_block, @pkg_info) = extract_code_block($self, 'Trigger', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'trigger'} = $trigger_block;
        } elsif ($line =~ m/^PreInstall/) {
            dbgmsg("DEBUG", "Found package keyword 'PreInstall' block");
            my $pre_inst_block = undef;
            ($pre_inst_block, @pkg_info) = extract_code_block($self, 'PreInstall', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'preInstall'} = $pre_inst_block;
        } elsif ($line =~ m/^PostInstall/) {
            dbgmsg("DEBUG", "Found package keyword 'PostInstall' block");
            my $post_inst_block = undef;
            ($post_inst_block, @pkg_info) = extract_code_block($self, 'PostInstall', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'postInstall'} = $post_inst_block;
        } elsif ($line =~ m/^PreUninstall/) {
            dbgmsg("DEBUG", "Found package keyword 'PreUninstall' block");
            my $pre_uninst_block = undef;
            ($pre_uninst_block, @pkg_info) = extract_code_block($self, 'PreUninstall', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'PreUninstall'} = $pre_uninst_block;
        } elsif ($line =~ m/^PostUninstall/) {
            dbgmsg("DEBUG", "Found package keyword 'PostUninstall' block");
            my $post_uninst_block = undef;
            ($post_uninst_block, @pkg_info) = extract_code_block($self, 'PostUninstall', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'postUninstall'} = $post_uninst_block;
        } elsif ($line =~ m/^PreTransaction/) {
            dbgmsg("DEBUG", "Found package keyword 'PreTransaction' block");
            my $pre_trans_block = undef;
            ($pre_trans_block, @pkg_info) = extract_code_block($self, 'PreTransaction', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'preTransaction'} = $pre_trans_block;
        } elsif ($line =~ m/^PostTransaction/) {
            dbgmsg("DEBUG", "Found package keyword 'PostTransaction' block");
            my $post_trans_block = undef;
            ($post_trans_block, @pkg_info) = extract_code_block($self, 'PostTransaction', @pkg_info);
            $bp_struct{'packages'}->{$pkg_name}->{'scripts'}->{'postTransaction'} = $post_trans_block;
        } elsif ($line =~ m/^FileList/) {
            dbgmsg("DEBUG", "Found package keyword 'FileList' block");
        }
    }

    return %bp_struct;
}

our sub strip_white_space_lines ($self, $bp_wc) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    foreach my $line (@{$bp_wc}) {
        if ($line eq "") {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
        }
    }
}

our sub process_blueprint_file ($self, $blueprint_file) {
    my $sub = (caller(0))[3];
    dbgmsg("TRACE", "sub: $sub");

    my %blueprint_structure = ();

    my $content_type = undef;
    my $bp_wc = undef;
    my $file = path($blueprint_file);
    my @blueprint_contents = $file->lines({ chomp => 1 });

    if (check_for_blueprint_block_bounding($self, @blueprint_contents) == true) {
        shift @blueprint_contents;
        pop @blueprint_contents;
        ($content_type, $bp_wc) = parse_pkg_type($self, @blueprint_contents);
        if (! defined $content_type) {
            dbgmsg("ERROR", $_errors{'EWRONGPKGTYPE'}->{'msg'} . ": Exiting");
            exit $_errors{'EWRONGPKGTYPE'}->{'code'};
        }
        strip_white_space_lines($self, $bp_wc);
        ($bp_wc, %blueprint_structure) = parse_bp_metadata($self, $content_type, @{$bp_wc});
        my @pkg_info;
        foreach my $pkg (@{$blueprint_structure{'package_list'}}) {
            dbgmsg("DEBUG", "Extracting package info for $pkg");
            my $start = undef;
            my $end   = undef;
            ($start, $end, @pkg_info) = extract_pkg_info($self, $pkg, \%blueprint_structure, \@{$bp_wc});
            dbgmsg("DEBUG", "Package info for $pkg starts on line $start and ends on line $end");
            # strip out this package from our working copy
            @{$bp_wc} = @{$bp_wc}[ (${end} + 1) .. $#{$bp_wc}];
            %blueprint_structure = parse_bp_pkgs($self, $pkg, \%blueprint_structure, @pkg_info);
        }
    }

    return %blueprint_structure;
}

true;
