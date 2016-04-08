#!/usr/bin/perl -w
#   Simple text coloring (e.g. for sequences)
#   Ryan Koehler 10/11/10
#   10/26/10 V0.2 RTK 
#   12/6/10 V0.3 RTK; Add -bc for case-dependent bold / no
#   12/1/12 RTK; V0.4; Add -wl for white lowercase
#   2/26/14 RTK V0.5; Add support for stdin "-"
#   3/14/14 RTK V0.51; Modularizie, clean and pretty (perlcritic)
#       Also add -win X
#   4/4/14 RTK V0.52; Rework with comarg
#   12/12/15 RTK; V.53; Add -row stuff; Get rid of -bc so always "bold"
#   12/24/15 RTK; V0.54; Add -bran -rre
#   1/7/16 RTK; V0.55; Add -cigv IGV color scheme
#   1/17/16 RTK; RTK V0.56; Generalize -not (from -rnot) to Run or Range
#   1/31/16 RTK; Fix -bran off-by-one sham (maybe new?)
#   4/7/16 RTK V0.57; Make lowercase work with not (inversion)
#

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
use Readonly;
use Carp;
use RTKUtil     qw(split_string);
use DnaString   qw(frac_string_dna_chars dna_base_degen dna_iub_match);

#   Constants for coloring scheme
Readonly my $VERSION => "color_seq.pl V0.57; RTK 4/7/16";
Readonly my $COLSCHEME_ORIG => 0;
Readonly my $COLSCHEME_ABI  => 1;
Readonly my $COLSCHEME_IGV  => 2;
Readonly my $COLSCHEME_GC   => 3;
Readonly my $COLSCHEME_WIN  => 4;
Readonly my $COLSCHEME_ONE  => 5;
Readonly my $COLSCHEME_DEF  => $COLSCHEME_ORIG;

Readonly my $DEF_WINSIZE    => 5;
Readonly my $DEF_RUNSIZE    => 3;

Readonly my $CHAR_STATE     => 'bold';


#   Supposed to make things nice with 'more' pager.... doesn't seem to matter!
$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = '\n';


###########################################################################
sub col_seq_use 
{
    print '=' x 77 . "\n";
    print "$VERSION\n";
    print "\n";
    print "Usage: <infile> ['-' for stdin] [...options]\n";
    print "  <infile>   Sequence file\n";
    print "  -cabi      Color scheme 'ABI' style\n";
    print "  -cigv      Color scheme 'IGV' style\n";
    print "  -corig     Color scheme 'original' style\n";
    print "  -cgc       Color scheme GC-warm / AT-cool style\n";
    print "  -win X     Color by windows of base type X (IUB is OK)\n";
    print "  -ws #      Window size #; Default is $DEF_WINSIZE\n";
    print "  -nacgt     Only color non-ACGT bases; IUB = red; Other = blue\n";
    print "  -run       Only color runs of bases\n";
    print "  -rs #      Run size #; Default is $DEF_RUNSIZE\n";
    print "  -lw        Lowercase ignored (i.e. upper = color, lower no)\n";
    print "  -all       Color all lines; Default ignores fasta '>' and comment '#'\n";
    print "  -bran # #  Limit base range # to # (1-base coords)\n";
    print "  -rre       Range relative to end; i.e. base range is backwards\n";
    print "  -not       NOT; Invert coloring so non-runs / out-of-range colored\n";
    print "  -verb      Verbose; print color mapping\n";
    print '=' x 77 . "\n";
    return;
}

###########################################################################
#
#   Main
#
{
    #
    #   Command line options
    #
    my $help = 0;
    my $do_stdin = 0;
    my $comargs = {
        'do_cabi'   => 0,
        'do_cigv'   => 0,
        'do_corg'   => 0,
        'do_cgc'    => 0,
        'do_nacgt'  => 0,
        'do_lw'     => 0,
        'win_size'  => $DEF_WINSIZE,
        'col_win'   => '',
        'do_run'    => 0,
        'run_size'  => $DEF_RUNSIZE,
        'do_not'   => 0,
        'do_all'    => 0,
        'bran'      => [],
        'do_rre'    => 0,
        'verb'      => 0,
    };
    my $options_ok = GetOptions (
        ''          => \$do_stdin,      # Empty string for only '-' as arg
        'help'      => \$help,
        'verb'      => \$comargs->{verbose},
        'cabi'      => \$comargs->{do_cabi},
        'cigv'      => \$comargs->{do_cigv},
        'corg'      => \$comargs->{do_corg},
        'cgc'       => \$comargs->{do_cgc},
        'nacgt'     => \$comargs->{do_nacgt},
        'lw'        => \$comargs->{do_lw},
        'win=s'     => \$comargs->{col_win},
        'ws=i'      => \$comargs->{win_size},
        'all'       => \$comargs->{do_all},
        'run'       => \$comargs->{do_run},
        'rs=i'      => \$comargs->{run_size},
        'not'       => \$comargs->{do_not},
        'bran=i{2}' => $comargs->{bran},
        'rre'       => \$comargs->{do_rre},
        );

    if ( ($help) || (!$options_ok) || ( (scalar @ARGV < 1)&&(!$do_stdin) ) ) {
        col_seq_use();
        exit 1;
    }
    my $INFILE = \*STDIN;
    if (! $do_stdin ) {
        my $fname = shift @ARGV;
        open ($INFILE, '<', $fname ) or croak "Failed to open $fname\n", $!;
    }
    #
    #   Set up colors and report 
    #
    my $colormap = set_up_colors($comargs);
    if ( ! $colormap ) {
        print "No colors = no fun!\n";
        exit 1;
    }
    report_colseq_settings($comargs, $colormap);

    #
    #   Process each line
    #
    while (my $line = <$INFILE> ) {
        # Comment
        if ( ($line =~ m/^\s*#/) && (! $comargs->{do_all}) ) {          
            print $line;
        }
        # Fasta header line 
        elsif ( ($line =~ m/^\s*>/ ) && (! $comargs->{do_all}) ) {       
            print $line;
        }
        else {
            dump_color_line($line, $colormap, $comargs);
        }
    }
    #   Clean up 
    close ($INFILE);
}

###########################################################################
sub report_colseq_settings
{
    my ($comargs, $colormap) = @_;
    if ( $comargs->{verbose} ) {
        if ( $comargs->{col_win} ) {
            print "# Windows of '$comargs->{col_win}'\n";
            print "#  Size $comargs->{win_size}\n";
            print "#  High (match) color =     $colormap->{'High'}\n";
            print "#  Low (anti-match) color = $colormap->{'Low'}\n";
            print "#  Otherwise, color =       $colormap->{'Mid'}\n";
        }
        else {
            print "# Color mapping:\n";
            foreach my $key ( sort keys %{$colormap} ) {
                my $story = $key . " => " . $colormap->{$key} . "\n";
                print "#  ";
                print_color_string($story, $colormap->{$key});
            }
        }
    }
}

###########################################################################
sub set_up_colors
{
    my $comargs = shift @_;

    my $colscheme = $COLSCHEME_DEF;
    if ( $comargs->{do_nacgt} ) {
        $colscheme = $COLSCHEME_ONE;
    }
    elsif ( $comargs->{col_win} ) {
        if ( ! dna_base_degen( $comargs->{col_win} ) ) {
            print "\nBad window arg '$comargs->{col_win}'; Must be IUB code\n\n";
            return '';
        }
        $colscheme = $COLSCHEME_WIN;
    }
    elsif ( $comargs->{do_cabi} ) {
        $colscheme = $COLSCHEME_ABI;
    }
    elsif ( $comargs->{do_corg} ) {
        $colscheme = $COLSCHEME_ORIG;
    }
    elsif ( $comargs->{do_cigv} ) {
        $colscheme = $COLSCHEME_IGV;
    }
    elsif ( $comargs->{do_cgc} ) {
        $colscheme = $COLSCHEME_GC;
    }
    my $colormap = get_color_map_hash($colscheme);
    return $colormap;
}

###########################################################################
#
#   Create and fill color mapping hash
#   Allowed colors: "blue","magenta","red","yellow","green","cyan","white","black"
#
sub get_color_map_hash
{
    my $scheme = shift @_;
    my $colormap = ();
    #
    #   Value-based colors, not alpabet
    #
    if ( $scheme == $COLSCHEME_WIN ) {
        $colormap = {
        'Low' => 'cyan', 
        'Mid' => 'white', 
        'High' => 'red', 
        };
    }
    #
    #   ABI trace style
    #
    elsif ( $scheme == $COLSCHEME_ABI ) {
        $colormap = {
        'A' => 'red', 
        'C' => 'blue', 
        'G' => 'green', 
        'T' => 'black', 
        };
    }
    #
    #   IGV display style
    #
    elsif ( $scheme == $COLSCHEME_IGV ) {
        $colormap = {
        'A' => 'green', 
        'C' => 'blue', 
        'G' => 'yellow', 
        'T' => 'red', 
        };
    }
    #
    #   GC warm, AT cool 
    #
    elsif ( $scheme == $COLSCHEME_GC ) {
        $colormap = {
        'A' => 'cyan', 
        'C' => 'red', 
        'G' => 'magenta', 
        'T' => 'blue', 
        };
    }
    #
    #   Original colors 
    #
    elsif ( $scheme == $COLSCHEME_ORIG ) {
        $colormap = {
        'A' => 'green', 
        'C' => 'red', 
        'G' => 'blue', 
        'T' => 'yellow', 
        };
    }
    else {
        print "SHAM $scheme";
        return 0;
    }
    #
    #   Default non-base colors
    #
    $colormap->{'IUB'} = 'red';
    $colormap->{'Non-IUB'} = 'cyan';
    $colormap->{'BackGrd'} = 'white';
    return $colormap;
}

###########################################################################
#
#   Dump out one line with (possibly) colored characters
#
sub dump_color_line
{
    my ($line, $colormap, $comargs) = @_;
    my $tokens = split_string($line);
    foreach my $word ( @{$tokens} ) {
        my $frac = frac_string_dna_chars($word);
        if ( $frac > 0.5 ) {
            if ( $comargs->{col_win} ) {
                color_word_wins($word, $colormap, $comargs);
            }
            else {
                dump_color_word($word, $colormap, $comargs);
            }
        }
        else {
            print $word;
        }
    }
    return;
}

###########################################################################
sub word_bran_bounds
{
    my ($word, $comargs) = @_;
    my $wordlen = length($word);
    my $firstb = -1;
    my $lastb = $wordlen;
    if (scalar @{ $comargs->{bran}} >= 2) {
        if ($comargs->{do_rre}) {
            $firstb = $wordlen - $comargs->{bran}[1] + 1;
            $lastb = $wordlen - $comargs->{bran}[0] + 1;
        }
        else {
            $firstb = $comargs->{bran}[0];
            $lastb = $comargs->{bran}[1];
        }
    }
    return ($firstb, $lastb);
}
###########################################################################
#
#   Dump out word with colored characters
#
sub dump_color_word
{
    my ($word, $colormap, $comargs) = @_;
    my ($curcol, $do_bkgd);
    #
    # Get color list and any row-color shams
    #
    my $ccolist = get_word_char_colors($word, $colormap, $comargs);
    my $runmask;
    if ( $comargs->{do_run} ) {
        $runmask = tally_color_run_mask($word, $comargs);
    }
    my $do_inv = $comargs->{do_not};
    my ($firstb, $lastb) = word_bran_bounds($word, $comargs);
    # Each char gets color; Reset start / end
    my $n = 0;
    print color('reset');
    foreach my $lchar ( split //, $word ) {
        $curcol = shift $ccolist;
        $do_bkgd = 0; 
        # Marked run ?
        if (($comargs->{do_run} ) && ( ! $runmask->[$n] )) {
            $do_bkgd = 1;
        }
        # Out of range?
        if (($n < $firstb) || ($n > $lastb)) {
            $do_bkgd = 1;
        }
        # Lowercase?
        if (( $comargs->{do_lw} ) && ( $lchar =~ m/[a-z]/x )) {
            $do_bkgd = 1;
        }
        # Inverse color qualification?
        $do_bkgd = $do_inv ? (!$do_bkgd) : ($do_bkgd);
        # Background or color?
        $curcol = $do_bkgd ? $colormap->{BackGrd} : $curcol;
        print color($CHAR_STATE, $curcol);
        print $lchar;
        $n++;
    }
    print color('reset');
    return;
}

###########################################################################
#
#   Get per-character color; Don't print
#   Return reference to color array
#
sub get_word_char_colors
{
    my ($word, $colormap, $comargs) = @_;
    my ($colkey, $curcol);
    #
    #   A character at a time
    #
    my @ccolist;
    foreach my $lchar ( split //, $word ) {
        $colkey = uc $lchar;     
        #
        #   Explicit color for key == normal DNA base
        #
        if ( exists $colormap->{$colkey} ) {
            $curcol = $colormap->{$colkey};
            #
            #   If highlighting non-IUB, make normal base background
            #
            if ( $comargs->{do_nacgt} ) {
                $curcol = $colormap->{BackGrd};
            }
        }
        #
        #   No explicit key = non-normal DNA base
        #
        else {
            if ( $comargs->{do_nacgt} ) {
                if ( dna_base_degen($lchar) > 0 ) {
                    $curcol = $colormap->{'IUB'};
                }
                else {
                    $curcol = $colormap->{'Non-IUB'};
                }
            }
            else {
                $curcol = $colormap->{BackGrd};
            }
        }
        push(@ccolist, $curcol);
    }
    return \@ccolist;
}

###########################################################################
#
#   Dump out word colors based on any windows of given char pattern
#
sub color_word_wins
{
    my ($word, $colormap, $comargs) = @_;
    my $curcol;

    my ($hscore, $lscore) = tally_color_win_masks($word, $comargs);
    my ($firstb, $lastb) = word_bran_bounds($word, $comargs);
    #
    #   Dump chars
    #
    my $n = 1;
    foreach my $lchar ( split //, $word ) {
        if ( $hscore->[$n] > 0 ) {
            $curcol = $colormap->{'High'};
        }
        elsif ( $lscore->[$n] > 0 ) {
            $curcol = $colormap->{'Low'};
        }
        else {
            $curcol = $colormap->{'Mid'};
        }
        # Out of range?
        if ( ($n < $firstb) || ($n > $lastb) ) {
            $curcol = $colormap->{BackGrd};
        }
        print color($CHAR_STATE, $curcol);
        print $lchar;
        $n++;
    }
    print color('reset');
    return;
}

###########################################################################
#
#   Get per-character "score" masks for window marking
#   Return reference to arrays
#
sub tally_color_win_masks
{
    my ($word, $comargs) = @_;
    my $col_win = $comargs->{col_win};
    my $win_size = $comargs->{win_size};
    #
    #   Tally up runs of match and anti-match along seq
    #
    my @hscore = (0);
    my @lscore = (0);
    my $n = 1;
    foreach my $lchar ( split //, $word ) {
        if ( dna_iub_match($lchar, $col_win) ) {
            $hscore[$n] = $hscore[$n - 1] + 1; 
            $lscore[$n] = 0;
        }
        else {
            $hscore[$n] = 0;
            $lscore[$n] = $lscore[$n - 1] + 1; 
        }
        $n++;
    }
    #
    #   Backfill, after first padding end
    #
    my $prev_h = 0;
    my $prev_l = 0;
    while ( $n > 0 ) {
        $n--;
        if ( ($hscore[$n] >= $win_size) || (($hscore[$n] > 0) && ($prev_h > 0)) ) {
            $hscore[$n] = $win_size;
        }
        else {
            $hscore[$n] = 0;
        }
        if ( ($lscore[$n] >= $win_size) || (($lscore[$n] > 0) && ($prev_l > 0)) ) {
            $lscore[$n] = $win_size;
        }
        else {
            $lscore[$n] = 0;
        }
        $prev_h = $hscore[$n];
        $prev_l = $lscore[$n];
    }
    return (\@hscore, \@lscore);
}

###########################################################################
#   
#   Get mask for run-based coloring
#   Returns reference to array
#
sub tally_color_run_mask
{
    my ($word, $comargs) = @_;
    my $min_run = $comargs->{run_size} - 1;
    my @rmask;
    #
    #   Forward pass, count max rows
    #
    my $row = 0;
    my $prevch = '';
    my $cchar;
    foreach my $lchar ( split //, $word ) {
        $cchar = uc $lchar;     
        if ( $cchar eq $prevch ) {
            $row ++;
        }
        else {
            $row = 0;
        }
        $prevch = $cchar;
        push(@rmask, $row);
    }
    #
    #   Second pass, cleaning and back filling rows 
    #
    my $n = scalar @rmask - 1;
    while ( $n > 0 ) {
        if ( $rmask[$n] >= $min_run ) {
            $row = $rmask[$n];
            while ( ($row >= 0) && ( $n >= 0 ) ) {
                #print("X$n ");
                $rmask[$n] = 1;
                $n--;
                $row--;
            }
        }
        else {
            #print("Y$n ");
            $rmask[$n--] = 0;
        }
        #print("$n=$rmask[$n] ");
    }
    return \@rmask;
}

###########################################################################
sub print_color_string
{
    my $word = shift @_;
    my $color = shift @_;
    print color($CHAR_STATE, $color);
    print $word;
    print color('reset');
}

