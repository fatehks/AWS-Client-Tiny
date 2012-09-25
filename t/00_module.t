# -*- Perl -*-

use strict;
use warnings;
use Data::Dumper;

use Test::More;

# Dummy values for testing
my $awskey  = "ABCDEFGHIJKLMNOPQRST";
my $awssecret =  "AbcDefGhiJklMnoPqrStuVwxYz1234567890AbcD";

BEGIN { 
	use_ok('AWS::Client::Tiny');
}

my $number_of_tests_run = 1;


my $aws = AWS::Client::Tiny->new($awskey, $awssecret);
is($aws->{'AWSAccessKeyId'}, $awskey);
is($aws->{'AWSAccessSecret'}, $awssecret);
$number_of_tests_run += 2;

my @services = qw(ec2 sqs elb sdb iam);
foreach my $service (@services) {
	is(ref($AWS::Client::Tiny::Info->{$service}), ref({}), "Lookup type $service info");

	ok(defined($AWS::Client::Tiny::Info->{$service}->{'version'}), "Lookup $service info version");
	ok(defined($AWS::Client::Tiny::Info->{$service}->{'service'}), "Lookup $service info service");
	my $serv = $aws->service($service);
	is($serv, $service, "get/set valid service, $service.");

	$number_of_tests_run += 4;
}

is(ref($AWS::Client::Tiny::Info->{'region'}), ref({}), "Lookup type region info");
$number_of_tests_run += 1;

my @regions = qw(us-east-1
				 us-west-2
				 us-west-1
				 eu-west-1
				 ap-southeast-1
				 ap-northeast-1
				 sa-east-1
			);
foreach my $region (@regions) {
	ok(defined($AWS::Client::Tiny::Info->{'region'}->{$region}), "Lookup $region info region");
	$number_of_tests_run += 1;
}


my @signatures = qw(HmacSHA1 HmacSHA256);
foreach my $sig (@signatures) {
	is(ref($AWS::Client::Tiny::SignatureMethod->{$sig}), ref(sub{}), "Lookup type sig $sig");
	ok(defined($AWS::Client::Tiny::SignatureMethod->{$sig}), "Lookup sig $sig");
	$number_of_tests_run += 2;
}

$aws->service("ec2");

### Check service_url construction
my $serv_url = $aws->service_url();
is($serv_url, "https://ec2.amazonaws.com", "Default EC2 service Url");

$aws->region("us-west-1");
$serv_url = $aws->service_url();
is($serv_url, "https://ec2.us-west-1.amazonaws.com", "Custom EC2 service Url");

$aws->region("default");
$number_of_tests_run += 2;


# Check endpoint get/set
foreach my $newregion (keys %{ $AWS::Client::Tiny::Info->{'region'} }) {
	my $oldep = $aws->endpoint();

	$aws->region($newregion);
	my $ep = $aws->endpoint();

	ok($oldep ne $ep, "endpoint set, old=$oldep, new=$ep");
	$number_of_tests_run += 1;
}

my $data = { "Foo" => "smoke", "Bar" => "mirrors" };
my $catparams = $aws->cat_params($data);

# Params should be sorted
is($catparams, "Bar=mirrors&Foo=smoke", "Cat parms");
$number_of_tests_run++;

foreach my $newregion (keys %{ $AWS::Client::Tiny::Info->{'region'} }) {
	$aws->region($newregion);
	$aws->use_http_get();
	my $ep = $aws->endpoint();
	my $calc = $aws->calculate_string_to_sign_v2($data);
	is($calc, "GET\n".$ep."\n/\nBar=mirrors&Foo=smoke", "Calculate String To Sign v2 GET");

	$aws->use_http_post();
	$calc = $aws->calculate_string_to_sign_v2($data);
	is($calc, "POST\n".$ep."\n/\nBar=mirrors&Foo=smoke", "Calculate String To Sign v2 POST");
	$number_of_tests_run += 2;
}

my $now = [ gmtime(time) ];
my $now_ts = sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
					 sub { ($_[5]+1900, $_[4]+1, $_[3], $_[2], $_[1], $_[0]) }->(@$now));
my $timestamp = $aws->formatted_timestamp($now);
is($timestamp, $now_ts, "Get formatted timestamp");
$number_of_tests_run++;


my $req = $aws->add_required_parameters($data);

ok(defined($req->{'AWSAccessKeyId'}), "Required Params defined awskey");
ok(defined($req->{'SignatureMethod'}), "Required Params defined sig method");
ok(defined($req->{'SignatureVersion'}), "Required Params defined sig version");
ok(defined($req->{'Version'}), "Required Params defined ec2 version");
ok(defined($req->{'Timestamp'}), "Required Params defined timestamp");
ok(defined($req->{'Signature'}), "Required Params defined signature");
$number_of_tests_run += 6;

is($req->{'AWSAccessKeyId'}, $awskey, "Required Params awskey");
is($req->{'SignatureMethod'}, "HmacSHA256", "Required Params sig method");
#is($req->{'SignatureMethod'}, "HmacSHA1", "Required Params sig method");
is($req->{'SignatureVersion'}, "2", "Required Params sig version");
is($req->{'Version'}, $AWS::Client::Tiny::Info->{'ec2'}->{'version'}, "Required Params ec2 version");
$number_of_tests_run += 4;



use URI::Escape qw(uri_escape_utf8);
my $string = "/abc/def~!@#$%^&*()-_+=";
my $escapepattern = "^A-Za-z0-9\-_.~";
my $string_esc = uri_escape_utf8($string, $escapepattern);
my $urlenc = $aws->urlencode($string);
is($urlenc, $string_esc, "urlencode");
$number_of_tests_run += 1;



### No more tests
done_testing( $number_of_tests_run );
