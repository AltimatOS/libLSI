package libLSI::Constants;

use strict;
use warnings;
use English;
use utf8;

use boolean;

use libLSI::Constants;

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, @EXPORT_TAGS);

    $VERSION     = $libLSI::Constants::VERSION;
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    @EXPORT_TAGS = (
        ALL => [
            qw ($author
                $lpkg_desc
                $license
                $copyright
            )
        ]
    );
    @EXPORT_OK   = qw(
        $author
        $lpkg_desc
        $license
        $copyright
    );
}

my $author    = "Gary L. Greene, Jr. <greeneg\@altiumatos.com>";
my $lpkg_desc = "part of the Linux Software Installer (LSI) suite";
my $license   = "Apache License, version 2.0";
my $copyright = "Copyright (C) 2014-2020 YggdrasilSoft, LLC.";

END {}

true;