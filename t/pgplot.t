BEGIN{
    # Set perl to not try to resolve all symbols at startup
    # The default behavior causes some problems because
    # the PGPLOT code defines interfaces for all PGPLOT functions
    # whether or not they are linked.
    $ENV{'PERL_DL_NONLAZY'}=0;
}

use strict;

use PDLA;
use Test::More;

sub eval_skip {
   eval "use $_[0]";
   plan skip_all => "$_[0] not installed" if $@;
}

BEGIN{
   eval_skip "PGPLOT";
   eval_skip "PDLA::Graphics::PGPLOT";
   eval_skip "PDLA::Graphics::PGPLOT::Window";
   plan skip_all => "DISPLAY environment variable not set"
      if !exists $ENV{'DISPLAY'} and !exists $ENV{HARNESS_ACTIVE};
}

plan tests => 20;

sub get_answer () {
    print STDERR "Does this look OK (y/n, y is default)? :";
    my $answer = <STDIN>;
    return $answer !~ m/n/i;
}

sub interactive ($$) {
    my $flag = shift;
    my $num  = shift;
    return unless $flag; # ie not interactive

    if (1 == $num) {
    print STDERR <<'EOD';
PGPLOT X device... you should see a 6 inch (153 mm) x 4 inch (102 mm)
X window with four plots in it.  All four images should have tick marks
on the outside of the axes.

[ Scaled image of m51; scale        [Scaled image of m51 with scale from
  in pixels on both axes ]           X=[-1.8, 2.0],Y=[-1.9, 1.9] arcmin,
				     with cal. wedge, centered in rect. frame]

[ Square image of m51; scale        [Square image of m51 with scale as above,
  in pixels on both axes;            ``shrink-wrapped'']
  ``shrinkwrapped'' ]

EOD
    } elsif (2 == $num) {
    print STDERR <<'EOD';
==============================================================

You should see four plots demonstrating pitch setting, justification,
and alignment:

[ Square image of m51 scaled to         [Short, squat image of m51 with
300 ppi (1.25 inches wide), aligned      aspect ratio 1:2, width 1.25 inch,
to bottom left corner of rect. plot      and height 0.625 inch, shrinkwrapped
box and cropped at the top.        ]     and placed at lower left of plot rgn]

[ Square image of m51 scaled to         [Tall, narrow image of m51 with
300 ppi (1.25 inches wide), aligned      aspect ratio 2:1, width 0.625 inch,
to upper right corner of rect. plot      and height 1.25 inch, shrinkwrapped
box and cropped at the bottom.     ]     and placed at upper right of plot rgn]

EOD
    } else {
      die "Internal error: unknown test number $num for interactive()!\n";
    }
    return get_answer();
}

my $interactive = exists($ENV{'PDLA_INT'});
my $skip_interactive_msg = "no interactive tests as env var PDLA_INT not set";
my $interactive_ctr = 0;

my $dev = $ENV{'PGPLOT_DEV'} ? $ENV{'PGPLOT_DEV'} : "/xw";

$dev = '/null' if exists $ENV{HARNESS_ACTIVE} and not $interactive;

my $w = PDLA::Graphics::PGPLOT::Window->new(
    Dev => $dev,
    Size=> [6,4],
    NX=>2, NY=>2,
    Ch=>2.5, HardCH=>2.5
);
isa_ok($w, "PDLA::Graphics::PGPLOT::Window");

my $x = rfits('m51.fits');

##############################
# Page 1
#
foreach my $str (
    '$w->imag($x,{Title=>"\$w->imag(\$x);"} );',
    '$w->fits_imag($x,{Title=>"\$w->fits_imag(\$x);"});',
    '$w->imag($x,{J=>1,Title=>"\$w->imag(\$x,{J=>1});"});',
    '$w->fits_imag($x,{J=>1,Title=>"\$w->fits_imag(\$x,{J=>1});"});'
) {
    my $result = eval $str;
    is $@, '', "eval '$str'";
    isnt $result, 0, 'returned true';
}

$interactive_ctr++;
SKIP: {
   skip $skip_interactive_msg, 1 unless $interactive;
   ok(interactive($interactive, $interactive_ctr), "interactive tests");
}

##############################
# Page 2
#
foreach my $str ( (
    '$w->imag($x,{Pitch=>300,Align=>"LB",Title=>"\$w->imag(\$x,{Pitch=>300,Align=>LB})"});',
    '$w->imag($x,{J=>.5,Pitch=>300,Align=>"LB",Title=>"\$w->imag(\$x,{J=>.5,Pitch=>300,Align=>LB})"});',
    '$w->imag($x,{Pitch=>300,Align=>"RT",Title=>"\$w->imag(\$x,{Pitch=>300,Align=>RT})"});',
    '$w->imag($x,{J=>2,Pitch=>600,Align=>"RT",Title=>"\$w->imag(\$x,{J=>2,Pitch=>600,Align=>RT})                     ."});',
    ) ) {
    my $result = eval $str;
    is $@, '', "eval '$str'";
    isnt $result, 0, 'returned true';
}

$interactive_ctr++;
SKIP: {
   skip $skip_interactive_msg, 1 unless $interactive;
   ok(interactive($interactive, $interactive_ctr), "interactive tests");
}

eval '$w->close';
is $@, '', "close window";
