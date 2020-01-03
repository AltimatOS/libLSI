use strict;
use warnings;

use libLSI::BlprntParser;

use boolean;
use Cwd;
use Path::Tiny;
use Test::More;
use Test::Output;

plan tests => 165;

# Testing validate_msg_level
my $result = undef;
# positive test
foreach my $lvl ("INFO", "DEBUG", "TRACE", "NOTICE",
                 "WARNING", "CRITICAL", "ALERT", "EMERGENCY") {
    $result = libLSI::BlprntParser::validate_msg_level($lvl);
    is($result, true, 'Is a valid message level');
}
# negative test
$result = libLSI::BlprntParser::validate_msg_level('ERR');
is($result, false, 'Invalid message level');

# Testing dbgmsg
# positive test
$ENV{'LSI_DEBUG'} = 1;
stderr_is { libLSI::BlprntParser::dbgmsg("INFO", "This is a test") }
    "INFO: This is a test\n", 'Testing STDERR output';

# negative test
$ENV{'LSI_DEBUG'} = undef;
stderr_is { libLSI::BlprntParser::dbgmsg("INFO", "This is a test") }
    "", 'Testing STDERR output';

# Testing process_blueprint_file
# do we get a hash back?
my $blpp = libLSI::BlprntParser->new();
my $cwd = getcwd;
my $bp_file = "$cwd/t/which.blprint";
is(ref {$blpp->process_blueprint_file($bp_file)}, 'HASH', "Test that returned result is a hash");

# Testing check_for_blueprint_block_bounding
my $file = path($bp_file);
my @bp = $file->lines({ chomp => 1 });
$result = $blpp->check_for_blueprint_block_bounding(@bp);
is($result, true, "Test that the blueprint is bounded by a Blueprint/End block");

# Testing parse_pkg_type
# positive test - throw away the array ref, since we're not going to use it
#     in the test later
($result, undef) = $blpp->parse_pkg_type(@bp);
is($result, 'software', "Test parsing out the pkgtype attribute and value");

# negative test
my @bad_bp = [
    'Blueprint',
    'pkgtype: commercial',
    'End'
];
($result, undef) = $blpp->parse_pkg_type(@bad_bp);
is($result, undef, "Test that unknown package types returns undef");

# Testing is_version_string
# lone digit version
$result = $blpp->is_version_string('1');
is($result, true, "Test digit only");

# major dot minor
$result = $blpp->is_version_string('1.0');
is($result, true, "Test major dot minor only");

# major dot minor dot patch
$result = $blpp->is_version_string('5.3.12');
is($result, true, "Test major dot minor dot patch (semver)");

# major dot minor rev-letter
$result = $blpp->is_version_string('1.0i');
is($result, true, "Test major dot minor rev-letter");

# openssl styled versions
$result = $blpp->is_version_string('1.1.1a');
is($result, true, "Test major dot minor dot patch and rev-letter (openssl styled)");

# series dot major dot minor dot patch (Microsoft versions and some kernels)
$result = $blpp->is_version_string('6.2.100.1998');
is($result, true, "Test series dot major dot minor dot patch");

# version and pre-release tags
foreach my $tag ("pre", "p", "alpha", "beta", "rc", "r",
                 "_pre", "_p", "_alpha", "_beta", "_rc", "_r",
                 ".pre", ".p", ".alpha", ".beta", ".rc", ".r",
                 "-pre", "-p", "-alpha", "-beta", "-rc", "-r") {
    # lone digit version
    $result = $blpp->is_version_string("1${tag}1");
    is($result, true, "Test digit only");

    # major dot minor
    $result = $blpp->is_version_string("1.0${tag}1");
    is($result, true, "Test major dot minor only");

    # major dot minor dot patch
    $result = $blpp->is_version_string("5.3.12${tag}1");
    is($result, true, "Test major dot minor dot patch (semver)");

    # major dot minor rev-letter
    $result = $blpp->is_version_string("1.0i${tag}1");
    is($result, true, "Test major dot minor rev-letter");

    # openssl styled versions
    $result = $blpp->is_version_string("1.1.1a${tag}1");
    is($result, true, "Test major dot minor dot patch and rev-letter (openssl styled)");

    # series dot major dot minor dot patch (Microsoft versions and some kernels)
    $result = $blpp->is_version_string("6.2.100.1998${tag}1");
    is($result, true, "Test series dot major dot minor dot patch");
}