# -*- Perl -*-

use strict;
use warnings;

use Test::More;

if (!defined($ENV{'NETWORK_TESTS'})) {
	plan skip_all => 'NETWORK_TESTS not set, skipping network tests.';
}

use_ok('AWS::Client::Tiny');
my $number_of_tests_run = 1;

my $awskey = "ABCDEFGHIJKLMNOP";
my $awssecret = "AaBbCcDdEeFfGg11223344556677889900";

my $aws = AWS::Client::Tiny->new($awskey, $awssecret);

# This is only a test to make sure that the
# http_post method works, it does not require
# access to aws
my $testurl = "http://search.cpan.org/search?";
my $testdata = {'mode'=>'module', 'query'=>'aws'};
my $testresponse = $aws->http_post($testurl, $testdata);
ok($testresponse->is_success, "http_post basic test");
$number_of_tests_run += 1;


### No more tests
done_testing( $number_of_tests_run );
