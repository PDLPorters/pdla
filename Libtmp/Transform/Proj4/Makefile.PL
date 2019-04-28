use strict;
use warnings;
use ExtUtils::MakeMaker;
use PDLA::Core::Dev;

my $package_name = "PDLA::Transform::Proj4";
my $lib_name = "Proj4";

our $have_alien_proj4;
BEGIN {
    $have_alien_proj4 = eval 'use Alien::Proj4';
}

if (!$have_alien_proj4) {
  write_dummy_make( <<EOF );
\tCannot find $lib_name installation.
\tPlease add the correct library path to perldl.conf or install $lib_name.
Skipping build of $package_name.
EOF
  return;
}

my $libflags = join ' ',  Alien::Proj4->libs;
my $incflags = Alien::Proj4->cflags;

print "Building $package_name.\n";

my $ppfile = "Proj4.pd";
my $package = [$ppfile, 'Proj4', $package_name];
my %hash = pdlpp_stdargs($package);
$hash{VERSION_FROM} = $ppfile;
#$hash{TYPEMAPS} = [&PDLA_TYPEMAP()];
$hash{LIBS} = [ $libflags ];
$hash{INC} = PDLA_INCLUDE() . " $incflags";
$hash{realclean} = { FILES => '' } unless $hash{realclean};
$hash{realclean}{FILES} .= ' _Inline';

undef &MY::postamble; # suppress warning
*MY::postamble = sub { pdlpp_postamble( $package ); };
WriteMakefile(%hash);
