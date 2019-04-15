use strict;
use warnings;
use ExtUtils::MakeMaker;

my @pack = (["compression.pd", qw(Compression PDLA::Compression)]);
my %hash = pdlpp_stdargs(@pack);

$hash{OBJECT} = "" unless exists $hash{OBJECT};
$hash{OBJECT} .= "ricecomp";

# Add genpp rule
undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble(@pack); };

WriteMakefile( %hash );
