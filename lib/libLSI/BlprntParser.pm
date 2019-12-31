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
use feature 'lexical_subs';
use feature 'signatures';

use boolean;
use Path::Tiny;
use libLSI::Constants;
use libLSI::Configuration;
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

my %keyword = (
    'blueprint' => 'Blueprint',
    'end'       => 'End'
);
my $cfg = libLSI::Configuration->new();
my $cfg_struct = $cfg->get();
if (! defined $cfg_struct) {
    say STDERR "ERROR: cannot read configuration file: Exiting";
    exit 1;
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
my sub check_for_blueprint_block_bounding ($self, @contents) {
    # trim leading and trailing whitespace...
    my $f_line = $contents[0];
    my $l_line = $contents[-1];

    say STDERR "DEBUG: first: $f_line";
    say STDERR "DEBUG: last: $l_line";
    say STDERR "DEBUG: Keyword blueprint: $keyword{blueprint}";
    say STDERR "DEBUG: Keyword blueprint: $keyword{end}";

    $f_line =~ s/^\s+|\s+$//g;
    $l_line =~ s/^\s+|\s+$//g;

    if ($f_line eq $keyword{blueprint} &&
        $l_line eq $keyword{end}) {
        return true;
    } else {
        return false;
    }
}

=head2 METHOD: parse_package_type

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

=back

=cut
my sub parse_package_type ($self, @bp_wc_contents) {
    foreach my $line (@bp_wc_contents) {
        $line =~ s/^\s+|\s+$//g;
        if ($line =~ m/^pkgtype:\s+(content|documentation|fonts|software)$/) {
            $line =~ s/pkgtype:\s+//;
            return $line;
        }
    }
    # otherwise...
    say STDERR "ERROR: Uknown package type! Exiting";
    exit 1;
}

=head2 METHOD: is_capability_name
=cut
my sub is_capability_name ($self, $string) {

}

my sub parse_bp_metadata ($self, $content_type, @bp_wc_contents) {
    my %bp_struct = ();

    say STDERR "DEBUG: Content Type: $content_type";
    # first trim leading whitespace
    foreach my $line (@bp_wc_contents) {
        # remove unneeded leading and trailing spaces
        $line =~ s/^\s+|\s+$//g;
        say STDERR "DEBUG: line: $line";

        # name takes a normal word value (no whitespace)
        if ($line =~ m/^name:\s+\w+$/) {
            say STDERR "TRACE: Found blueprint 'name' keyword";
            $line =~ s/name:\s+//;
            $bp_struct{'name'} = $line;
        }
        # version takes semver values
        if ($line =~ m/^version:\s+\d+?(\.\d+)?(\*|\.\d+)$/) {
            say STDERR "TRACE: Found blueprint 'version' keyword";
            $line =~ s/version:\s+//;
            # test that the version is an acceptable semver format
            $bp_struct{'version'} = $line;
        }
        # release takes a number + a trailing distribution tag
        if ($line =~ m/^release:\s+\d+.*$/) {
            say STDERR "TRACE: Found blueprint 'release' keyword";
            $line =~ s/release:\s+//;
            # test that the release is an acceptable release value
            $bp_struct{'release'} = $line;
        }
        if ($line =~ m/^distribution:\s+\w+$/) {
            say STDERR "TRACE: Found blueprint 'distribution' keyword";
            $line =~ s/distribution:\s+//;
            # Is the distribution known?
            $bp_struct{'distribution'} = $line;
        }
        if ($line =~ m/^license:\s+([a-zA-Z0-9\.\_\-\+\(\)]+)$/) {
            say STDERR "TRACE: Found blueprint 'license' keyword";
            $line =~ s/license:\s+//;
            # test that this is a valid open source license. If not,
            #   set the taint flag
            my $lic_validator = libLSI::LicenseValidation->new();
            if ($lic_validator->validate($content_type, $line) == true) {
                say STDERR "DEBUG: License Valitation for license $line: true";
                $bp_struct{'license'} = $line;
            } else {
                say STDERR "DEBUG: License Valitation for license $line: false";
                exit 1;
            }
        }
        $bp_struct{'pkgtype'} = $content_type;
        if ($line =~ m/^buildrequires:\s+(\w+|\,|\s+)+$/) {
            say STDERR "TRACE: Found blueprint 'buildrequires' keyword";
        }
    }

    return %bp_struct;
}

our sub process_blueprint_file ($self, $blueprint_file) {
    my %blueprint_structure;

    my $content_type = "";
    my $file = path($blueprint_file);
    my @blueprint_contents = $file->lines({ chomp => 1 });
    my @_blueprint_working_copy;

    if (check_for_blueprint_block_bounding($self, @blueprint_contents) == true) {
        shift @blueprint_contents;
        pop @blueprint_contents;
        $content_type = parse_package_type($self, @blueprint_contents);
        %blueprint_structure = parse_bp_metadata($self, $content_type, @blueprint_contents);
    }

    return %blueprint_structure;
}

true;