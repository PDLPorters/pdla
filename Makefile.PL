use strict;
use warnings;

# using absolute path to make it valid also for Makefile.PL files in subdirectories
use Cwd;
use lib Cwd::abs_path('inc');

use Devel::CheckLib;
use 5.010_000;
use ExtUtils::MakeMaker 6.56;  # for CONFIGURE_REQUIRES support
use Config;
use File::Spec;
use PDLA::Core::Dev;
use PDLA::Config;

$::PP_VERBOSE = $::PP_VERBOSE = 0; # =1 makes PP waffle a lot

# file globals(!)
my ($pdl_f77conf, $forcebuild);
my ($seen_pdlconf, $seen_f77conf);
my $pdl_conf_file = ''; # apparently for users to change

# build-system globals
our ($usenan, $bvalflag, $bvalPerPdl);

sub checkbuggysetup {
    # detect buggy Perl setups
    if (!$forcebuild &&
	$Config{osname} eq 'solaris' &&
	($Config{cc} =~ /gcc/ || $Config{gccversion} ne '') &&
	$Config{usemymalloc} eq 'y'
	) {
	die <<'EOM';

FATAL BUG IN YOUR PERL SETUP DETECTED. BUILD TERMINATED.

On this platform the combination of gcc and the Perl malloc
are buggy. The optimizations lead to random coredumps
and make PDLA essentially unusable.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
WORKAROUND: YOU MUST RECOMPILE PERL WITH 'usemymalloc=n' !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

You may override and force the build by including the
'FORCE' switch:

  perl Makefile.PL FORCE

However, you will most likely end up with an unusable
PDLA build unless *all* optimizations are disabled!
YOU HAVE BEEN WARNED!!

EOM
  }

    my($dot);
    for(@INC) {$dot += $_ eq '.'}
    $dot-- if($INC[-1] eq '.');
    if($dot) {
	$INC = join(":",@INC);
	warn << "EOM"

**********************************************************************
Your Perl \@INC path is:

$INC

That seems to include the directory '.' before the last entry in the
path.  Configurations like that might be broken, because they may
prevent strict division of hierarchy in the module name space.
In particular, adding a module Foo::Bar::Baz can cause trouble
if Baz exists in the top level elsewhere, and if you run from the
Foo/Bar directory.

This happens with the PDLA::Config and some other modules.  You may
not be able to build PDLA with this \@INC setup.

If you strike trouble, you may need to fix your \@INC.
**********************************************************************


EOM
unless $ENV{PDLA_INC_OK};
}

}

# Scan ARGV for config file argument
@ARGV = map {
	if(/^PDLACONF=(.*)$/) {
		$seen_pdlconf=1;
		$pdl_conf_file = $1; ();
	} elsif (/^F77CONF=(.*)$/) {
		$seen_f77conf=1;
		$pdl_f77conf=$1; ();
	} elsif (/^FORCE$/i) {
		$forcebuild=1;
		();
        } else {
		$_
	}
} @ARGV;

warn "WARNING: forcing build...\n" if $forcebuild;

checkbuggysetup(); # check for buggy Perl setups

unless ( $seen_pdlconf ) {
    my $defname = "$ENV{HOME}/.perldl.conf";
    $pdl_conf_file = $defname if -f $defname;
}

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

my @podpms = map { $_.".pod", '$(INST_LIBDIR)/PDLA/' . $_ .".pod"}
  qw/Bugs/;

my @prereq = (
	   'Astro::FITS::Header' => 0,
           'Carp'                => 0,         # Need to run
           'Config'              => 0,         # 
           'Convert::UU'         => 0,         # for PDLA::IO::Dumper
           'Data::Dumper'        => 2.121,     # for PDLA::IO::Dumper
           'English'             => 0,
           'ExtUtils::MakeMaker' => 6.56,      # for CONFIGURE_REQUIRES support
           'ExtUtils::Manifest'  => 0,
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
	   'Module::Compile'     => 0.23,      # for new PDLA::NiceSlice
           'PDLA::Core' => '2.013007',
	   'Pod::Parser'         => 0,         # version TBD for PDLA::Doc
	   'Pod::Select'         => 0,         # version TBD for PDLA::Doc
           'Scalar::Util'        => 0,
           'Storable'            => 1.03,      # for PDLA::IO::Storable
	   'Text::Balanced'      => 1.89,      # for PDLA::NiceSlice
	  );

# add OpenGL version dependency for CPAN to follow
push @prereq, ('OpenGL' => $PDLA::Config{POGL_VERSION}) if $PDLA::Config{USE_POGL};

# push @prereq, ('ExtUtils::F77' => 1.10) unless $seen_f77conf;

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

my %makefile_hash = (
	      'PREREQ_PM' => { @prereq },
              'CONFIGURE_REQUIRES' => {
                'PDLA::Core' => '2.013007',
                'Devel::CheckLib' => 1.01,
                'Carp'            => 1.20,    # EU::MM seems to need this not to crash
                'ExtUtils::MakeMaker' => 6.56,
                'File::Path'          => 0,
                'ExtUtils::Depends' => '0.402',
                'Alien::HDF4' => 0,
              },
              TEST_REQUIRES => {
                'CPAN::Meta' => '2.120900',
                'Test::Exception' => 0,
                'Test::Warn' => 0,  # for t/pptest.t
                'Test::Deep' => 0,
              },
              BUILD_REQUIRES => {
                'ExtUtils::MakeMaker' => 0,
                'ExtUtils::ParseXS'   => 3.01, # avoids 2.21, known broken
                'File::Path'          => 0,
              },
              'MIN_PERL_VERSION' => '5.010',
	      'NAME' => 'PDLA::Rest',
	      'VERSION_FROM' => 'lib/PDLA/Rest.pm',
	      'PM' => { @podpms }, #so that the script docs are picked up
              'META_MERGE' => {
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
                no_index => { file => ['Doc/scantree.pl'] },
              },
	      'OPTIMIZE'  => $PDLA::Config{OPTIMIZE} || $Config{optimize},
	      'CCFLAGS' => $ccflags,
	      'dist'     => { COMPRESS => 'gzip',
                              SUFFIX   => 'gz',
                              PREOP    => $preop },
	      'clean' => {
		'FILES' => join ' ', @cleanup, qw(
                  tbyte.tif tmp0 tmp0.hdr tushort.tif
                  MANIFEST.bak tmp1* tmpraw* t/tmpraw* t/tmp1*
                  _Inline/ .inlinepdlpp/ .inlinewith/ *.xfig
                ),
              },
              'AUTHOR' => 'PerlDL Developers (pdl-general@lists.sourceforge.net)',
              'ABSTRACT' => 'Perl Data Language',
              'BINARY_LOCATION' => 'PDLA.tar.gz',

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
  my  $text =
'
doctest ::
	$(NOECHO) $(ECHO) "doctest: Building PDLA documentation database in blib ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl
%HTML%	$(NOECHO) $(ECHO) "doctest: Building PDLA documentation web pages in blib ..."
%HTML%	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)mkhtmldoc.pl

doc_site_install ::
	$(NOECHO) $(ECHO) "doc_site_install: Building PDLA documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLSITEARCH)"
%HTML%	$(NOECHO) $(ECHO) "doc_site_install: Building PDLA documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLSITEARCH)$(DFSEP)PDLA"

doc_vendor_install ::
	$(NOECHO) $(ECHO) "doc_vendor_install: Building PDLA documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLVENDORARCH)"
%HTML%	$(NOECHO) $(ECHO) "doc_vendor_install: Building PDLA documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLVENDORARCH)$(DFSEP)PDLA"

doc_perl_install ::
	$(NOECHO) $(ECHO) "doc_perl_install: Building PDLA documentation database ..."
	$(NOECHO) $(PERLRUNINST) Doc$(DFSEP)scantree.pl "$(INSTALLARCHLIB)"
%HTML%	$(NOECHO) $(ECHO) "doc_perl_install: Building PDLA documentation web pages ..."
%HTML%	$(NOECHO) $(PERL) Doc$(DFSEP)mkhtmldoc.pl "$(INSTALLARCHLIB)$(DFSEP)PDLA"
';

  if(defined $PDLA::Config{HTML_DOCS} && !$PDLA::Config{HTML_DOCS}){
    $text=~ s/\%HTML\%[^\n]*\n//og; # Remove %HTML% lines
  } else {
    $text=~ s/\%HTML\%//og; # Remove just %HTML% markers
  }

$text .= << 'EOT' if $^O =~ /MSWin/;

DISTWIN32NAME=$(DISTVNAME)-win32

ppm : doctest ppd
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

$text .= "\n" . ::coretarget($self);
my $coretest = join ' ', map File::Spec->catfile('t', $_), qw(core.t ops.t);
$text .= <<EOF;

coretest : core
	prove -b $coretest
EOF

return $text

}

sub coretarget {
    my ($self) = @_;
    # remember the fundamental ones end up far to right as much deps on them
    # a "right" is either scalar (named target) or tuple of
    #     [ \@dir, \@targets, \@prereqs ]
    # @dir is dir parts for use by File::Spec
    # @targets is make targets within that dir
    # @prereqs are named targets - undef=[]
    # all a left's rights are made concurrently, no sequence - list ALL prereqs
    my @left2rights = (
        [
            basics => [
                [ [ qw(Basic) ], [ qw(pm_to_blib) ], ],
                [ [ qw(Basic Core) ], [ qw(pm_to_blib) ], ],
                [ [ qw(Basic Gen) ], [ qw(all) ], ],
            ]
        ],
        [
            core => [
                [ [ qw(Basic SourceFilter) ], [ qw(pm_to_blib) ], ],
                map { [
                    [ 'Basic', $_ ],
                    [ 'pm_to_blib', 'dynamic' ],
                    [ 'basics' ],
                # the modules in PDLA::LiteF, used in t/core.t
                ] } qw(Core Ops Primitive Ufunc Slices Bad Math MatrixOps),
            ]
        ],
    );
    join "\n", map flatten_parallel_target($self, $_), @left2rights;
}

sub format_chunk {
    my ($self, $left, $deps, $dir, $targets) = @_;
    my @m = join ' ', $left, ':', @{$deps||[]};
    my $fsdir = File::Spec->catdir(@$dir);
    push @m, "\t" . $self->oneliner(
        "die \$! unless chdir q($fsdir); exec q(\$(MAKE) @$targets)"
    );
    join '', map "$_\n", @m;
}

# output: list of make chunks with target, deps, recipes
sub flatten_parallel_target {
    my ($self, $left2rights) = @_;
    my ($left, $rights) = @$left2rights;
    my (@deps, @recipes, @otherchunks);
    for my $right (@$rights) {
        if (ref $right) {
            #     [ \@dir, \@targets, \@prereqs ]
            # @dir is dir parts for use by File::Spec
            # @targets is make targets within that dir
            # @prereqs are named targets - undef=[]
            my ($dir, $targets, $prereqs) = @$right;
            my $target_name = parallel_target_mangle($self, $dir, $targets);
            push @deps, $target_name;
            push @otherchunks, format_chunk(
                $self, $target_name, $prereqs, $dir, $targets
            );
        } else {
            push @deps, $right;
        }
    }
    (
        join(' : ', $left, join ' ', @deps) . "\n",
        @otherchunks,
    );
}

sub parallel_target_mangle {
    my ($self, $dir, $targets) = @_;
    my $target = join '_', @$dir, @$targets;
    $target =~ s#[/\\]#_#g; # avoid ambiguity with filenames
    $target;
}

# remove pdl.c from making EUMM think this dir has XS in it
sub MY::init_dirscan {
    package MY;
    my ($self) = @_;
    $self->SUPER::init_dirscan;
    $self->{C} = [];
    $self->{O_FILES} = [];
}

##############################
# processPL: generate Makefile lines for top-level components that are created by just perling a .PL file.
#EU::MM's processPL() is continually broken on Win32 ... hence:
### This fix seems necessary with current versions of MM - otherwise it creates circular
### dependencies to "pm_to_blib" for .PL files (!) -- CED 9-July-2008
sub MY::processPL {
    package MY;
    my ($self) = @_;
    return $self->SUPER::processPL if 0; ## || $^O =~ /MSWin32/i && $Config{make} =~ /\b[dn]make/i
    return "" unless $self->{PL_FILES};
    my @m;
    my $alltarget = 'all';
    my $colon = $Config::Config{make} =~ /\bdmake/i ? ':' : '::';
    foreach my $plfile (sort keys %{$self->{PL_FILES}}) {
        my $list = ref($self->{PL_FILES}->{$plfile})
                     ?  $self->{PL_FILES}->{$plfile}
                     : [$self->{PL_FILES}->{$plfile}];
        foreach my $target (@$list) {
            push @m,
                "\n$alltarget :: $target\n\t\$(NOECHO) \$(NOOP)\n",
                "\n$target $colon\n\t\$(PERLRUNINST) $plfile $target\n";
        }
    }
    return join "", @m;
}
