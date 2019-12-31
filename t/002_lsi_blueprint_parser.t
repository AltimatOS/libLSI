use strict;
use warnings;

use libLSI::BlprntParser;

use boolean;
use Test::More;
use Test::Output;

plan tests => 11;

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
