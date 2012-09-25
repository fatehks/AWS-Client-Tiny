package AWS::Client::Tiny;  # -*- Perl -*-

# Time-stamp: <2012-08-31 11:50:54 dhisel>

=head1 NAME

AWS::Client::Tiny - access AWS services with the least amount of dependencies

=head1 SYNOPSIS

  use AWS::Client::Tiny;
  my $aws = AWS::Client::Tiny->new($awskey, $awssecret);

  my $response = $aws->ec2('Action' => 'DescribeInstances');
  if ($response->is_success) {
  	print $response->content;
  }
  print $response->code;
  

=head1 DESCRIPTION

The main purpose of AWS::Client::Tiny is to create a signature, send the query
to the service, and return the data.  There is no data transformation.

Some useful AWS documentation:

http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/Welcome.html

=cut

use 5.010001;
use strict;
use warnings;

use LWP::UserAgent;
use URI::Escape qw(uri_escape_utf8);
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64);

our $VERSION = '0.05';

=head2 Region Endpoints

EC2 http://docs.amazonwebservices.com/general/latest/gr/rande.html#ec2_region

               Region                            Endpoint                Protocol   
US East (Northern Virginia) Region   ec2.us-east-1.amazonaws.com      HTTP and HTTPS
US West (Oregon) Region              ec2.us-west-2.amazonaws.com      HTTP and HTTPS
US West (Northern California) Region ec2.us-west-1.amazonaws.com      HTTP and HTTPS
EU (Ireland) Region                  ec2.eu-west-1.amazonaws.com      HTTP and HTTPS
Asia Pacific (Singapore) Region      ec2.ap-southeast-1.amazonaws.com HTTP and HTTPS
Asia Pacific (Tokyo) Region          ec2.ap-northeast-1.amazonaws.com HTTP and HTTPS
South America (Sao Paulo) Region     ec2.sa-east-1.amazonaws.com      HTTP and HTTPS

If you just specify the general endpoint (ec2.amazonaws.com), Amazon EC2 directs your request to the
us-east-1 endpoint.

=cut

our $Info = {
	'region' => {
		# Region => Endpoint
		'default'        => 'amazonaws.com',
		'us-east-1'      => 'us-east-1.amazonaws.com',
		'us-west-2'      => 'us-west-2.amazonaws.com',
		'us-west-1'      => 'us-west-1.amazonaws.com',
		'eu-west-1'      => 'eu-west-1.amazonaws.com',
		'ap-southeast-1' => 'ap-southeast-1.amazonaws.com',
		'ap-northeast-1' => 'ap-northeast-1.amazonaws.com',
		'sa-east-1'      => 'sa-east-1.amazonaws.com', 
	},
	'ec2' => {
		'version' => "2010-11-15",
		'service' => "ec2",
	},
	'mon' => { # cloudwatch
		'version'  => "2010-08-01",
		'service' => "monitoring",
	},
	'sqs' => {
		'version' => "2009-02-01",
		'service' => "queue",
	},
	'elb' => {
		'version' => "2010-07-01",
		'service' => "elasticloadbalancing",
	},
	'sdb' => {
		'version' => "2009-04-15",
		'service' => "sdb",
	},
	'iam' => {
		'version'  => "2010-05-08",
		'service' => "iam",
	},
	'rds' => {
		'version'  => "2012-07-31",
		'service' => "rds",
	},

	# valid schemes
	'scheme' => {
		'default' => 'https',
		'http' => 'http',
		'https' => 'https',
	},
};

our $SignatureMethod = {
	'HmacSHA1'   => sub { hmac_sha1_base64($_[0], $_[1])   },
	'HmacSHA256' => sub { hmac_sha256_base64($_[0], $_[1]) },
};


=head1 METHODS

=head3 new($awskey, $awssecret)

Takes AWS Access Key Id, and AWS Secret as parameters.

=cut

sub new {
	my $class = shift;
	my $awskey = shift;
	my $awssecret = shift;
	my $self = {
		'AWSAccessKeyId' => $awskey,
		'AWSAccessSecret' => $awssecret,
		'SignatureMethod' => "HmacSHA256",
		'SignatureVersion' => "2",

		'http_method' => "POST",
		'service' => "ec2",
		'region' => 'default',
		'scheme' => 'default',
		@_
	};
	return bless $self, $class;
}

=head2 AWS Signature V2 Helper Methods

=head3 calculate_string_to_sign_v2($hashref_parameters)

=cut

sub calculate_string_to_sign_v2 {
	my ($self, $params) = @_;
	return "" unless ref($params) eq ref({});
	return join "\n", ($self->{'http_method'},
					   $self->endpoint(),
					   "/",
					   $self->cat_params($params));
}

=head3 sign($hashref_parameters)

=cut

sub sign {
	my ($self, $params) = @_;
	return $SignatureMethod->{$self->{'SignatureMethod'}}->(
		$self->calculate_string_to_sign_v2($params),
		$self->{'AWSAccessSecret'})  ."=";
}

=head3 calculate_string_to_sign_v2($hashref_parameters)

See the amazon doc for how the params should be prepared,
http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/using-query-api.html

=cut

sub add_required_parameters {
	my ($self, $params) = @_;
	$params->{'AWSAccessKeyId'} = $self->{'AWSAccessKeyId'};
	$params->{'Timestamp'} = $self->formatted_timestamp();
	$params->{'Version'} = $Info->{$self->service()}->{'version'};
	$params->{'SignatureMethod'} = $self->{'SignatureMethod'};
	$params->{'SignatureVersion'} = $self->{'SignatureVersion'};
	$params->{'Signature'} = $self->sign($params);
	return $params;
}

=head3 endpoint($method)

=cut

sub endpoint {
	my ($self) = @_;
	return $Info->{$self->service()}->{'service'} .".". $Info->{'region'}->{ $self->region() }
}

=head3 service_url($method)

=cut

sub service_url {
	my ($self, $method) = @_;
	return "https://".$self->endpoint();
}

=head3 invoke($method, $params_hashref)

=cut

sub invoke {
	my ($self, $method, $params) = @_;
	if (exists $Info->{$method}) {
		$self->service($method);
		return $self->http_post(
			$self->service_url($method),
			$self->add_required_parameters($params)
		);
	}
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	our $AUTOLOAD;
	return if $AUTOLOAD =~ /::DESTROY$/;
	my ($pkg, $method) = $AUTOLOAD =~ m/(.*)::(\w+)$/;
	return $self->invoke($method, {@_});
}

=head2 Getters and Setters

=head3 use_http_post()

This sets the http method to be "POST" and returns $self.

=cut

sub use_http_post { 
	$_[0]->{'http_method'} = "POST";
	$_[0];
}

=head3 use_http_get()

This sets the http method to be "GET" and returns $self.

=cut

sub use_http_get {
	$_[0]->{'http_method'} = "GET";
	$_[0];
}


=head3 scheme($scheme_name)

=cut

sub scheme {
	my ($self, $scheme) = @_;
	return $self->{'scheme'} unless defined($scheme);
	$self->{'scheme'} = $scheme if	exists($Info->{'scheme'}->{$scheme});
}

=head3 region($region_name)

=cut

sub region {
	my ($self, $region) = @_;
	return $self->{'region'} unless defined($region);
	$self->{'region'} = $region if	exists($Info->{'region'}->{$region});
}

=head3 service($optional_service_name)

The parameter is optional.  This is a get/set method.  It always
returns the value that is stored in the instance.

=cut

sub service {
	my ($self, $service) = @_;
	return $self->{'service'} unless defined($service);
	$self->{'service'} = $service if exists($Info->{$service});
}

=head2 Helpers

=head3 urlencode($value, $path)

=cut

sub urlencode {
	my ($self, $value, $path) = @_;
	my $escapepattern = "^A-Za-z0-9\-_.~";
	if ($path) {
	    $escapepattern = $escapepattern . "/";
	}
	return uri_escape_utf8($value, $escapepattern);
}

=head3 cat_params($hashref_parameters)

Returns a string of catenated params, or an empty string if params are
not passed as a hash ref.

See the amazon doc for how the params should be prepared,
http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/using-query-api.html

=cut

sub cat_params {
	my ($self, $params) = @_;
	return "" unless ref($params) eq ref({});
	join "&",
	map { $_."=".$self->urlencode($params->{$_}) } 
	sort keys %{$params};
}

=head3 http_post($url, $hashref_parameters)

Returns an HTTP::Response object.

=cut

sub http_post {
	my ($self, $url, $parameters) = @_;
	my $data = $self->cat_params($parameters);
	my $request= HTTP::Request->new("POST", $url);
	$request->content_type("application/x-www-form-urlencoded; charset=utf-8");
	$request->content($data);

	LWP::UserAgent->new->request($request);
}

=head3 formatted_timestamp()

Returns a string timestamp that is a properly formatted for AWS V2
signature.

=cut

sub formatted_timestamp {
	my ($self, $time) = @_;
	$time ||= [ gmtime(time) ];
	return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.000Z",
				   sub { ($_[5]+1900, $_[4]+1, $_[3], $_[2], $_[1], $_[0]) }->(@$time)
			   );
}

1;

__END__


=head1 SEE ALSO

=head1 AUTHOR

David Hisel, E<lt>fatehks@cameltime.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by David Hisel

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
