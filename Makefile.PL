# -*- Perl -*-
#
# Time-stamp: <2012-08-07 08:04:07 dhisel>
#
use 5.010001;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'AWS::Client::Tiny',
    VERSION_FROM      => 'lib/AWS/Client/Tiny.pm', # finds $VERSION
    PREREQ_PM         => {
		'Digest::SHA' => 5.4, # tested with 5.47 (Core Module)
		'URI::Escape' => 3.2, # tested with 3.29
		'LWP::UserAgent' => 5.8, # tested with 5.834
	},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
	 (ABSTRACT_FROM  => 'lib/AWS/Client/Tiny.pm', # retrieve abstract from module
	  AUTHOR         => 'f(x) <fatehks@cameltime.com>') : ()),
);
