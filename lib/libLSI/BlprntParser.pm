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

use boolean;
use Data::Dumper;
use List::MoreUtils;
use Path::Tiny;

use libLSI::Constants;
use libLSI::Configuration;
use libLSI::Errors;
use libLSI::LicenseValidation;

# my $dsl = Marpa::R2::Scanless->G->new(
#     {
#         action_object  = 'BlprntActions';
#         default_action = 'default_action';
#         source         = \(<<'EO_DSL'),
# start             ::= block_blueprint
# 
# block_blueprint   ::= keyword_blueprint
#                         attribs_blueprint
#                       keyword_end
# 
# block_pkg         ::= keyword_binary_pkg
#                         attribs_pkg
#                       keyword_end
# 
# block_build       ::= keyword_build t_string_arch
#                         1(block_prep)
#                         1(block_compile)
#                         1[block_check]
#                         1(block_install)
#                       keyword_end
# 
# block_prep        ::= keyword_prep
#                         1*t_string_line
#                       keyword_end
# 
# block_check       ::= keyword_check
#                         1*t_string_line
#                       keyword_end
# 
# block_compile     ::= keyword_compile
#                         1*t_string_line
#                       keyword_end
# 
# block_install     ::= keyword_install
#                         1*t_string_line
#                       keyword_end
# 
# block_chglog      ::= keyword_changelog
#                         1*(block_chglog_entry)
#                       keyword_end
# 
# block_chglog_entry ::= c_record t_date t_nickname t_email c_separator t_pkgver c_nline c_entry t_string_record
# 
# block_description ::= keyword_description
#                         1*t_string_line
#                       keyword_end
# 
# block_filelist    ::= keyword_filelist
#                         1*t_string_line
#                       keyword_end
# 
# block_trigger     ::= keyword_trigger t_capability
#                         1*t_string_line
#                       keyword_end
# 
# block_preinst     ::= keyword_preinstall
#                         1*t_string_line
#                       keyword_end
# 
# block_postinst    ::= keyword_postinstall
#                         1*t_string_line
#                       keyword_end
# 
# block_preuninst   ::= keyword_preuninstall
#                         1*t_string_line
#                       keyword_end
# 
# block_postuninst  ::= keyword_postuninstall
#                         1*t_string_line
#                       keyword_end
# 
# attribs_blueprint ::= 1(glbl_pkgname)
#                       | [glbl_epoch]
#                       | 1(glbl_version)
#                       | 1(glbl_release)
#                       | 1*glbl_build_requires
#                       | 1*glbl_sources
#                       | [*glbl_patches]
#                       | 1(glbl_root_bld)
#                       | 1(glbl_buildroot)
#                       | 1*block_pkg
#                       | 1*block_build
#                       | 1(block_chglog)
# 
# attribs_pkg       ::= 1(attrib_pkgname)
#                       | 1(attrib_summary)
#                       | 1*attrib_pkgtags
#                       | 1(attrib_pkggrp)
#                       | [*attrib_requires]
#                       | 1(block_description)
#                       | [*block_trigger]
#                       | [ block_preinst | block_postinst | block_preuninst | block_postuninst ]
#                       | 1(block_filelist)
# 
# glbl_pkgname    ::= keyword_name c_assign t_string_ascii
# 
# glbl_epoch      ::= keyword_epoch c_assign t_int
# 
# glbl_version    ::= keyword_version c_assign t_semversion
# 
# glbl_release    ::= keyword_release c_assign t_int
# 
# glbl_build_requires  ::= keyword_buildrequires c_assign t_capability
# 
# glbl_sources    ::= (keyword_source(t_int)) c_assign t_string_filename
# 
# glbl_patches    ::= (keyword_patch(t_int)) c_assign t_string_filename
# 
# glbl_root_bld   ::= keyword_require_root_build c_assign t_bool
# 
# attrib_pkgname  ::= keyword_pkgname c_assign t_string_ascii
# 
# attrib_summary  ::= keyword_summary c_assign t_string_line
# 
# attrib_pkggrp   ::= keyword_group c_assign t_string_group
# 
# attrib_pkgtags  ::= keyword_tag c_assign 1*(t_string_tag)
# 
# attrib_requires ::= keyword_require c_assign 1*(t_capability)
# 
# keyword_blueprint          ~ 'Blueprint'
# keyword_build              ~ 'Build'
# keyword_buildrequires      ~ 'buildrequires'
# keyword_changelog          ~ 'ChangeLog'
# keyword_check              ~ 'BuildCheck'
# keyword_compile            ~ 'BuildCompile'
# keyword_description        ~ 'Description'
# keyword_epoch              ~ 'epoch'
# keyword_end                ~ 'End'
# keyword_group              ~ 'group'
# keyword_install            ~ 'BuildInstall'
# keyword_name               ~ 'name'
# keyword_package            ~ 'Package'
# keyword_patch              ~ 'patch'
# keyword_pkgname            ~ 'pkgname'
# keyword_postinstall        ~ 'PostInstall'
# keyword_postuninstall      ~ 'PostUninstall'
# keyword_preinstall         ~ 'PreInstall'
# keyword_prep               ~ 'BuildPrep'
# keyword_preuninstall       ~ 'PreUninstall'
# keyword_require_root_build ~ 'root_required_for_build'
# keyword_release            ~ 'release'
# keyword_require            ~ 'requires'
# keyword_source             ~ 'source'
# keyword_summary            ~ 'summary'
# keyword_tag                ~ 'tags'
# keyword_version            ~ 'version'
# keyword_license            ~ 'license'
# keyword_url                ~ 'url'
# keyword_chksum             ~ 'chksum'
# keyword_chksum_type        ~ 'chksumtype'
# keyword_src_signature      ~ 'srcsignature'
# 
# operator        ::= op_eq
#                     | op_gt
#                     | op_lt
#                     | op_ge
#                     | op_le
#                     
# op_eq           ~   '=='
# op_gt           ~   '>'
# op_lt           ~   '<'
# op_ge           ~   '>='
# op_le           ~   '<='
# 
# c_assign        ~   ':'
# 
# c_comma         ~   ','
# 
# c_record        ~   '*'
# 
# c_separator     ~   '|'
# 
# c_nline         ~   "\n"
# 
# c_entry         ~   '-'
# 
# t_capability    ::= t_pkg_word [ operator t_semversion ]
#                     | t_string_filename
# 
# t_date          ::= t_year t_month t_day
# 
# t_month         ::= 'Jan' | 'Feb' | 'Mar' | 'Apr' | 'May' | 'Jun' | 'Jul' | 'Aug' | 'Sep' | 'Oct' | 'Nov' | 'Dec'
# 
# t_day           ::= 2(t_digit)
# 
# t_year          ::= 4(t_digit)
# 
# t_digit         ~   [\d]
# 
# t_int           ~   [\d+]
# 
# t_nickname      ~   [\w+]
# 
# t_email         ~   [[a-zA-Z\d\.+]\@[a-zA-Z\d\.+]]
# 
# t_bool          ::= true | false
# true            ~   1
# false           ~   0
# 
# t_string_ascii    ~ [^[a-zA-Z\-]+$]
# t_string_line     ~ [^.*$]
# t_string_filename ~ [^\w+$]
# t_string_tag      ~ [\w](c_comma)
# t_string_group    ~ [[a-zA-Z\d]+\/]
# 
# t_semversion      ~ [^(\d+\.)?(\d+\.)?(\*|\d+)$]
# EO_DSL
#     }
# );

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
    say STDERR "ERROR: " . $_errors{'ENOENT'}->{'msg'} . ": Exiting";
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

    if (defined $ENV{'LSI_DEBUG'}) {
        say STDERR "$level: $msg";
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
    if ($string =~ m/^/) {}
}

our sub parse_srcpkg_name ($self, $bp_wc) {
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        # name takes a normal word value (no whitespace)
        if ($line =~ m/^name:\s+\w+$/) {
            dbgmsg("TRACE", "Found blueprint 'name' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^name:\s+//;
            dbgmsg("TRACE", "blueprint 'name' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub is_version_string ($self, $version_string) {
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
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^version:\s+.*$/) {
            dbgmsg("TRACE", "Found blueprint 'version' keyword");
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            $line =~ s/^version:\s+//;
            if (is_version_string($self, $line)) {
                dbgmsg("TRACE", "blueprint 'version' value: $line");
                return $line;
            }
        }
    }
    return undef;
}

our sub parse_pkg_release ($self, $bp_wc) {
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\+s$//g;

        if ($line =~ m/^release:\s+\d+.*$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("TRACE", "Found blueprint 'release' keyword");
            $line =~ s/^release:\s+//;
            dbgmsg("TRACE", "blueprint 'release' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub parse_pkg_distribution ($self, $bp_wc) {
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^distribution:\s+\w+$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("TRACE", "Found blueprint 'distribution' keyword");
            $line =~ s/^distribution:\s+//;
            dbgmsg("TRACE", "blueprint 'distribution' value: $line");
            return $line;
        }
    }
    return undef;
}

our sub parse_pkg_license ($self, $content_type, $bp_wc) {
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^license:\s+([a-zA-Z0-9\.\_\-\+\(\)]+)$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("TRACE", "Found blueprint 'license' keyword");
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
    return split(', ', $string);
}

our sub make_caps_struct ($self, @cap_list) {
    my %cap_struct;
    foreach my $ent (@cap_list) {
        dbgmsg("TRACE", "cap_list entry: $ent");
        if ($ent =~ m|^/[a-z/]+$|) {
            dbgmsg("TRACE", "Capability type: file_path");
            $cap_struct{"$ent"} = { 'type' => 'file_path' };
        } elsif ($ent =~ m/^\w+$/) {
            dbgmsg("TRACE", "Capability type: unpinned_pkg");
            $cap_struct{"$ent"} = { 'type' => 'unpinned_pkg' };
        } elsif ($ent =~ m|^(\w+\s+\>\<\=\!\s+.*)$|) {
            dbgmsg("TRACE", "Capability type: pinned_pkg");
            my ($pkg_name, $cmp_expression, $version) = split(/\s+/, $ent);
            $cap_struct{"$pkg_name"} = { 'type' => 'pinned_pkg' };
            $cap_struct{"$pkg_name"} = { 'cmpexp' => "$cmp_expression" };
            $cap_struct{"$pkg_name"} = { 'version' => "$version" };
        }
    }
    return %cap_struct;
}

our sub parse_pkg_build_requires ($self, $bp_wc) {
    foreach my $line (@{$bp_wc}) {
        $line =~ s/^\s+|\s+$//g;

        if ($line =~ m/^buildrequires:\s+([\w+\,\s+]+)$/) {
            @{$bp_wc} = grep { $_ ne $line } @{$bp_wc};
            dbgmsg("TRACE", "Found blueprint 'buildrequires' keyword");
            $line =~ s/buildrequires:\s+//;
            # parse capabilities
            my @cap_list = parse_capabilities($self, $line);
            my %cap_struct = make_caps_struct($self, @cap_list);
            return \%cap_struct;
        }
    }
    return undef;
}

our sub parse_pkg_buildroot ($self, $bp_wc) {

}

my sub parse_bp_metadata ($self, $content_type, @bp_wc_contents) {
    my %bp_struct = ();

    dbgmsg("DEBUG", "Content Type: $content_type");
    # first trim leading whitespace
    foreach my $line (@bp_wc_contents) {
        dbgmsg("DEBUG", "line: $line");
    }

    $bp_struct{'pkgtype'} = $content_type;
    $bp_struct{'srcpkg_name'}  = parse_srcpkg_name($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'version'}      = parse_pkg_version($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'release'}      = parse_pkg_release($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'distribution'} = parse_pkg_distribution($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    ($bp_struct{'license'},
     $bp_struct{'foss'}    )   = parse_pkg_license($self, $content_type, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'buildrequires'} = parse_pkg_build_requires($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);
    $bp_struct{'buildroot'} = parse_pkg_buildroot($self, \@bp_wc_contents);
    dbgmsg("TRACE", "BP lines: ". scalar @bp_wc_contents);

    return %bp_struct;
}

our sub process_blueprint_file ($self, $blueprint_file) {
    my %blueprint_structure;

    my $content_type = undef;
    my $bp_wc = undef;
    my $file = path($blueprint_file);
    my @blueprint_contents = $file->lines({ chomp => 1 });
    my @_blueprint_working_copy;

    if (check_for_blueprint_block_bounding($self, @blueprint_contents) == true) {
        shift @blueprint_contents;
        pop @blueprint_contents;
        ($content_type, $bp_wc) = parse_pkg_type($self, @blueprint_contents);
        if (! defined $content_type) {
            dbgmsg("ERROR", $_errors{'EWRONGPKGTYPE'}->{'msg'} . ": Exiting");
            exit $_errors{'EWRONGPKGTYPE'}->{'code'};
        }
        %blueprint_structure = parse_bp_metadata($self, $content_type, @{$bp_wc});
    }

    return %blueprint_structure;
}

true;