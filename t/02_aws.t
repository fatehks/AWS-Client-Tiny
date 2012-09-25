# -*- Perl -*-

use strict;
use warnings;

use Test::More;

if (!defined($ENV{'NETWORK_TESTS'})) {
	plan skip_all => 'NETWORK_TESTS not set, skipping aws tests.';
}

# See load_config() for notes on file format
our $aws_file = $ENV{'HOME'}."/.ec2/aws-keys";

if (!-f $aws_file) {
	plan skip_all => "AWS key file, $aws_file, not found, skipping aws tests.";
}

=head3 load_config($filename)

Config file format is expected to be in this format,

  AWSAccessKeyId=YOUR_ACCESS_KEY_ID
  AWSSecretKey=YOUR_SECRET_KEY

=cut

sub load_config {
	my $file = shift;
	my $fh = IO::File->new($file, "r");
	warn "Warning, file not read, $file, returning empty list." unless $fh;
	return () unless $fh;
	my @config;
	foreach (<$fh>) {
		next if /^\s*#/ || /^\s*$/;
		push @config, map {	s/^\s+//;s/\s+$//;$_ } split('=',$_,2);
	}
	return @config;
}

use_ok('AWS::Client::Tiny');
my $number_of_tests_run = 1;

my %config = load_config($aws_file);
my $aws = AWS::Client::Tiny->new($config{'AWSAccessKeyId'}, $config{'AWSSecretKey'});

my $response = $aws->ec2(
	'Action' => 'DescribeInstances',
	'Filter.1.Name' => 'tag-value',
	'Filter.1.Value' => 'ZZZ find nothing ZZZ',
);
ok($response->is_success, "ec2 Describe Instances basic test");
$number_of_tests_run += 1;

$aws->region("us-west-1");
$response = $aws->ec2(
	'Action' => 'DescribeInstances',
	'Filter.1.Name' => 'tag-value',
	'Filter.1.Value' => 'ZZZ find nothing ZZZ',
);
ok($response->is_success, "ec2 custom region Describe Instances basic test");
$number_of_tests_run += 1;

### No more tests
done_testing( $number_of_tests_run );
