use strict;
use warnings;
use ExtUtils::MakeMaker;
use PDLA::Core::Dev;

my @pack = (["transform.pd", qw(Transform PDLA::Transform)]);
my %hash = pdlpp_stdargs(@pack);

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble(@pack); };

WriteMakefile( %hash );
