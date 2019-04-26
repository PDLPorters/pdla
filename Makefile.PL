use strict;
use warnings;

# using absolute path to make it valid also for Makefile.PL files in subdirectories
use Cwd;
use lib Cwd::abs_path('inc');

eval { require Devel::CheckLib; Devel::CheckLib->import; };
use 5.010_000;
use ExtUtils::MakeMaker 6.56;  # for CONFIGURE_REQUIRES support
use Config;
use File::Spec;
use PDLA::Core::Dev;
use PDLA::Config;

$::PP_VERBOSE = $::PP_VERBOSE = 0; # =1 makes PP waffle a lot

# Check environment for SKIP_KNOWN_PROBLEMS
if (!defined($PDLA::Config{SKIP_KNOWN_PROBLEMS}) and defined($ENV{SKIP_KNOWN_PROBLEMS})) {
   $PDLA::Config{SKIP_KNOWN_PROBLEMS} = $ENV{SKIP_KNOWN_PROBLEMS};
   warn "Makefile.PL: setting SKIP_KNOWN_PROBLEMS Config from environment value: $ENV{SKIP_KNOWN_PROBLEMS}";
}
# Add check for POGL if USE_POGL is enabled
if (!defined($PDLA::Config{USE_POGL}) or +$PDLA::Config{USE_POGL}) {
   eval "use OpenGL $PDLA::Config{POGL_VERSION} qw();";
   if ($@) {
      if (defined($PDLA::Config{USE_POGL})) {
         warn "Makefile.PL: DEPENDENCY ERROR: USE_POGL requires at least OpenGL version $PDLA::Config{POGL_VERSION}!\n";
         exit 0;
      } else {
         warn "Makefile.PL: OpenGL-$PDLA::Config{POGL_VERSION} not found, setting \$PDLA::Config{USE_POGL} => 0\n";
         $PDLA::Config{USE_POGL} = 0;
      }
   } else {
      # Have OpenGL so set USE_POGL option if needed
      warn "Makefile.PL: Found required OpenGL version, setting USE_POGL => 1\n" unless defined($PDLA::Config{USE_POGL});
      $PDLA::Config{USE_POGL} ||= 1;
   }
} else {
   warn "Makefile.PL: Have \$PDLA::Config{USE_POGL} => 0 so skipping TriD build with POGL\n";
}

my @coredep = ('PDLA::Core' => '2.019100');
my @prereq = (
	   'Astro::FITS::Header' => 0,
           'Carp'                => 0,         # Need to run
           'Config'              => 0,         # 
           'Convert::UU'         => 0,         # for PDLA::IO::Dumper
           'Data::Dumper'        => 2.121,     # for PDLA::IO::Dumper
           'Fcntl'               => 0,
           'File::Basename'      => 0,
           'File::Find'          => 0,
	   'File::Map'           => 0.57,      # test new mmap implementation
           'File::Path'          => 0,
	   'File::Spec'          => 0.6,
	   'File::Temp'          => 0,
	   'Filter::Util::Call'  => 0,         # for PDLA::NiceSlice
	   'Filter::Simple'      => 0.88,      # for new PDLA::NiceSlice
	   'Inline'              => 0.68,
	   'Inline::C'           => 0.62,
	   'List::MoreUtils'     => 0,         # for PDLA::IO::GD
	   'Module::Compile'     => 0.23,      # for new PDLA::NiceSlice
	   @coredep,
	   'Pod::Parser'         => 0,         # version TBD for PDLA::Doc
	   'Pod::Select'         => 0,         # version TBD for PDLA::Doc
           'Scalar::Util'        => 0,
           'Storable'            => 1.03,      # for PDLA::IO::Storable
	   'Text::Balanced'      => 1.89,      # for PDLA::NiceSlice
	  );

# add OpenGL version dependency for CPAN to follow
push @prereq, ('OpenGL' => $PDLA::Config{POGL_VERSION}) if $PDLA::Config{USE_POGL};

my @cleanup = (qw(
    t/callext$(OBJ_EXT) t/callext.$(DLEXT)
));

##############################
# Hack to include fPIC on x86_64 systems -
# use similar mods to affect CCFLAGS on other systems as needed...

my $ccflags =  $Config{ccflags};
if($Config{archname}=~m/x86_64/) {
    $ccflags .= " -fPIC";
}

# create GENERATED subdir with *.pm files during 'make dist' (to make metacpan.org happy)
my $preop = '$(PERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -MPDLA::Core::Dev -e pdlpp_mkgen $(DISTVNAME)';

my @optimize = (OPTIMIZE => $PDLA::Config{OPTIMIZE}) if $PDLA::Config{OPTIMIZE};

my %makefile_hash = (
  PREREQ_PM => { @prereq },
  LICENSE => 'perl',
  CONFIGURE_REQUIRES => {
    @coredep,
    'Devel::CheckLib' => 1.01,
    'Carp'            => 1.20,    # EU::MM seems to need this not to crash
    'ExtUtils::MakeMaker' => 6.56,
    'File::Path'          => 0,
    'ExtUtils::Depends' => '0.402',
    'Alien::HDF4' => 0,
    'ExtUtils::ParseXS'   => 3.01, # avoids 2.21, known broken
  },
  TEST_REQUIRES => {
    'CPAN::Meta' => '2.120900',
    'Test::Exception' => 0,
    'Test::Warn' => 0,  # for t/pptest.t
    'Test::Deep' => 0,
    'ExtUtils::Manifest'  => 0,
  },
  BUILD_REQUIRES => {
    'ExtUtils::MakeMaker' => 0,
    'File::Path'          => 0,
  },
  MIN_PERL_VERSION => '5.010',
  NAME => 'PDLA::Rest',
  VERSION_FROM => 'lib/PDLA/Rest.pm',
  META_MERGE => {
    "meta-spec" => { version => 2 },
    resources => {
      homepage => 'http://pdlporters.github.io',
      bugtracker  => {web=>'https://github.com/PDLPorters/pdla-rest/issues'},
      repository  => {
        url => 'git://github.com/PDLPorters/pdla-rest',
        type => 'git',
        web => 'https://github.com/PDLPorters/pdla-rest',
      },
      x_IRC => 'irc://irc.perl.org/#pdl',
    },
  },
  @optimize,
  CCFLAGS => $ccflags,
  dist     => { COMPRESS => 'gzip',
                  SUFFIX   => 'gz',
                  PREOP    => $preop },
  clean => {
    FILES => join ' ', @cleanup, qw(
      tbyte.tif tmp0 tmp0.hdr tushort.tif
      MANIFEST.bak tmp1* tmpraw* t/tmpraw* t/tmp1*
      _Inline/ .inlinepdlpp/ .inlinewith/ *.xfig
    ),
  },
  AUTHOR => 'PerlDL Developers (pdl-general@lists.sourceforge.net)',
  ABSTRACT => 'Perl Data Language',
  BINARY_LOCATION => 'PDLA.tar.gz',
);

=begin comment

print "makefile hash is:\n";
for $k(sort keys %makefile_hash) {
    print "\t$k\t";
    $v = $makefile_hash{$k};
    unless(ref $v) {
	print $v,"\n";
    } elsif(ref $v eq 'HASH') {
	print "HASH:\n";
	for $vk(sort keys %$v) {
	    print "\t\t$vk\t$v->{$vk}\n";
	}
    } elsif(ref $v eq 'ARRAY') {
	print "ARRAY:\n";
	for $vv(@$v) {
	    print "\t\t$vv\n";
	}
    } else {print "$v\n";}

}

=end comment

=cut

WriteMakefile(%makefile_hash);

# do *after* WriteMakefile since some options
# are set by the recursively called Makefile.PLs

# Extra build target to build the doc database
sub MY::postamble {
  my ($self) = @_;
  package MY;
  my  $text = "\n";
$text .= << 'EOT' if $^O =~ /MSWin/;

DISTWIN32NAME=$(DISTVNAME)-win32

ppm : ppd
	$(MV) blib$(DFSEP)lib$(DFSEP)PDLA$(DFSEP)HtmlDocs$(DFSEP)PDLA blib$(DFSEP)html$(DFSEP)lib$(DFSEP)PDLA
	$(COMPRESS) -dc win32$(DFSEP)pbmwin32.tar.gz | $(TAR) xf -
	$(MKPATH) $(DISTWIN32NAME)
	$(CP) win32$(DFSEP)Readme $(DISTWIN32NAME)
	$(CP) win32$(DFSEP)install.ppm .
	$(PERL) -pe "s|<\x{2f}IMPLEMENTATION>|<INSTALL EXEC=\"perl\">install.ppm<\x{2f}INSTALL><\x{2f}IMPLEMENTATION>|" PDLA.ppd > PDLA.ppd.new
	$(RM) PDLA.ppd
	$(MV) PDLA.ppd.new PDLA.ppd
	$(CP) PDLA.ppd $(DISTWIN32NAME)
	$(TAR) cf $(DISTWIN32NAME)$(DFSEP)PDLA.tar blib install.ppm
	cd $(DISTWIN32NAME)
	$(COMPRESS) PDLA.tar
	$(ZIP) $(DISTWIN32NAME).zip *
	$(MV) $(DISTWIN32NAME).zip ..
	cd ..
	$(RM_RF) $(DISTWIN32NAME)
EOT

return $text

}
