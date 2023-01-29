#!/usr/bin/env perl
# #!/usr/bin/env perl -w
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
#   5/29/16 RTK; Fix -bran off-by-one sham (Works now!)
#   11/18/16 RTK; Replace reset() with set_bold_white() 
#   10/7/17 v0.59 RTK; Change 'shift' on ccolist ref to avoid warning; 
#       Fix but with -nacgt
#   12/20/19 V0.6; RTK; Put split_string and dna stuff explicitly
#   2023-01-28 RTK V0.7; Remove Readonly dependence
#

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
use Carp;

#   Constants for coloring scheme
my $VERSION = "color_seq.pl V0.7; RTK 2023-01-28";
my $COLSCHEME_ORIG = 0;
my $COLSCHEME_ABI  = 1;
my $COLSCHEME_IGV  = 2;
my $COLSCHEME_GC   = 3;
my $COLSCHEME_WIN  = 4;
my $COLSCHEME_ONE  = 5;
my $COLSCHEME_DEF  = $COLSCHEME_ORIG;

my $DEF_WINSIZE    = 5;
my $DEF_RUNSIZE    = 3;

my $CHAR_STATE     = 'bold';

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
    print "  -corg      Color scheme 'original' style\n";
    print "  -cgc       Color scheme GC-warm / AT-cool style\n";
    print "  -win X     Color by windows of base type X (IUB is OK)\n";
    print "  -ws #      Window size #; Default is $DEF_WINSIZE\n";
    print "  -nacgt     Only color non-ACGT bases; IUB = red; Other = blue\n";
    print "  -run       Only color runs of bases\n";
    print "  -rs #      Run size #; Default is $DEF_RUNSIZE\n";
    print "  -lw        Lowercase white (i.e. upper = color, lower no)\n";
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
    #
    #   non-ACGT case
    #
    elsif ( $scheme == $COLSCHEME_ONE ) {
        $colormap = {
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
            $firstb = $wordlen - $comargs->{bran}[1];
            $lastb = $wordlen - $comargs->{bran}[0];
        }
        else {
            $firstb = $comargs->{bran}[0] -1;
            $lastb = $comargs->{bran}[1] -1;
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
        # 'shift' directly on ref yields warning; cast to array
        #$curcol = shift $ccolist;
        $curcol = shift @{ $ccolist };
        $do_bkgd = 0; 
        # Marked run ?
        if (($comargs->{do_run} ) && ( ! $runmask->[$n] )) {
            $do_bkgd = 1;
        }
        # Out of range?
        if (($n < $firstb) || ($n > $lastb)) {
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
    #print color('reset');
    set_bold_white();
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
            #
            #   Case dependent shams?
            #
            if ( $lchar =~ m/[a-z]/x ) {
                if ( $comargs->{do_lw} ) { 
                    $curcol = 'white';
                }
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
    #print color('reset');
    set_bold_white();
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

sub set_bold_white
{
    print color('bold', 'white');
}

##############################################################################
#   
#   Split string into list of with / without tokens based on char class.
#   Default char class is space, so tokens would be words + spaces
#   If second argument, this is used in regex to match; Default = '\s'
#
sub split_string 
{
    my $in_string = shift @_;
    my $regex = ( (scalar @_) > 0) ? shift @_ : '\s';
    #
    #   Initialize
    #
    my @tokens = ();
    my $tok = '';
    my $pstate = -1;
    #
    #   For each character, compare previous "state" building like-state tokens
    #
    foreach my $lchar ( split(//,$in_string ) ) {
        my $state = ( $lchar =~ m/$regex/ ) ? 1 : 0;
        if ( $state != $pstate ) {
            if (length $tok) {
                push( @tokens, $tok);
                $tok = '';
            }
            $pstate = $state;
        }
        $tok .= $lchar;
    }
    if (length $tok) {
        push( @tokens, $tok);
    }
    return \@tokens;
}


my $dna_iub_match_hash = {
    'AA'=>1, 'AW'=>1, 'AR'=>1, 'AM'=>1, 'AD'=>1, 'AH'=>1, 'AV'=>1, 'AN'=>1, 
    'CC'=>1, 'CS'=>1, 'CY'=>1, 'CM'=>1, 'CB'=>1, 'CH'=>1, 'CV'=>1, 'CN'=>1, 
    'GG'=>1, 'GS'=>1, 'GR'=>1, 'GK'=>1, 'GB'=>1, 'GD'=>1, 'GV'=>1, 'GN'=>1, 
    'TT'=>1, 'TW'=>1, 'TY'=>1, 'TK'=>1, 'TB'=>1, 'TD'=>1, 'TH'=>1, 'TN'=>1, 
};

###########################################################################
#
#   Returns degeneracy of base (first letter in string)
#
sub dna_base_degen
{
    my $start = uc shift @_;
    my $deg = 0;
    if ( $start =~ m/^[ACGT]/ ) {
        $deg = 1;
    }
    elsif ( $start =~ m/^[SWRYMK]/ ) {
        $deg = 2;
    }
    elsif ( $start =~ m/^[BDHV]/ ) {
        $deg = 3;
    }
    elsif ( $start =~ m/^N/ ) {
        $deg = 4;
    }
    return $deg;
}

###########################################################################
#
#   Does the first base 'match' the second base (given IUB rules)
#
sub dna_iub_match
{
    my $b1 = uc shift @_;
    my $b2 = uc shift @_;
    my $key = $b1.$b2;
    my $m = defined($dna_iub_match_hash->{$key}) ? 1 : 0;
    return $m
}

###########################################################################
#
#   Reverse complement of passed sequence (string) 
#
sub seq_rev_comp
{
    my $dna = shift @_;
    my $revcomp = reverse($dna);
    $revcomp =~ tr/ACGTacgtSWRYMKswrymk/TGCAtgcaWSYRKMwsyrkm/;
    return $revcomp;
}

###########################################################################
#
#   Find and return sequence part of string
#
sub get_seq_in_string
{
    my $start = shift @_;
    my $seq = '';
    #
    #   Replace everything but letters with spaces, then split on spaces
    #   We will process each "word" 
    #
    $start =~ s/[^a-z,A-Z]/ /g;
    my @parts = split(' ', $start);
    foreach my $sham ( @parts ) {
        #
        #   Count ACGTN -vs- not
        #
        my @letters = string_dna_chars($sham);
        if ( $letters[4] ) {    # Any non-letters = sham token
            next;
        }
        #
        #   If (ACGT + N) > (IUB + other), add this "word" to sequence
        #
        if ( ($letters[0] + $letters[1]) > ($letters[2] + $letters[3]) ) {
            $seq .= $sham;
        }
    }
    return $seq;
}

###########################################################################
#
#   Count ACGTN chars in string
#   Returns ACGT, N, IUB, alphabet chars, other chars
#
sub string_dna_chars
{
    my $start = uc shift @_;
    my $nbase = scalar $start =~ s/[ACGT]//g;
    my $nn = scalar $start =~ s/N//g;
    my $niub = scalar $start =~ s/[SWRYMKBDHVU]//g;
    my $nlet = scalar $start =~ s/[A-Z]//g;
    my $noth = scalar $start =~ s/^\s//g;
    return($nbase, $nn, $niub, $nlet, $noth); 
} 

###########################################################################
#
#   Returns the fraction of non-space chracters in string that are "DNA"
#   If second argument, then count N or IUB chars as DNA
#
sub frac_string_dna_chars
{
    my $sham = uc shift @_;
    my $ok_iub = ( (scalar @_) > 0) ? shift @_ : 0;
    #   Strip spaces
    $sham =~ s/\s//g;
    my $len = length($sham);
    if ( $len < 1 ) {
        return 0.0;
    }
    #
    #   Fraction = 'DNA' / total
    #
    my @letters = string_dna_chars($sham);
    my $num = $letters[0];
    if ( $ok_iub > 0 ) {
        $num += $letters[1];
        if ( $ok_iub > 1 ) {
            $num += $letters[2];
        }
    }
    return ( $num / $len );
}

