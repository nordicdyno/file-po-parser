#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'File::PO::Parser' ) || print "Bail out!\n";
}

diag( "Testing File::PO::Parser $File::PO::Parser::VERSION, Perl $], $^X" );
