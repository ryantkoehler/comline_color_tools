#!/usr/bin/env perl 
# #!/usr/bin/env perl -w
#   Simple text coloring of numbers
#   Ryan Koehler 3/17/14; Modified from color_seq.pl
#   4/4/14 RTK V0.2; Update with comargs 
#   5/15/14 RTK V0.21; Add -iz
#   11/18/16 RTK; Replace reset() with set_bold_white()
#   12/20/19 RTK V0.3; Put split_string explicitly 
#

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
use Readonly;
use Carp;

Readonly my $VERSION => "color_nums.pl V0.3; RTK 12/20/19";

#   Constants for coloring scheme
Readonly my $COLSCHEME_DEF  => 0;
Readonly my $COLSCHEME_RYC  => 1;
Readonly my $COLSCHEME_RWB  => 2;
Readonly my $COLSCHEME_QUAL => 3;

Readonly my $DEF_QUAL_COLOR => 'cyan';
Readonly my $DEF_BACK_COLOR => 'white';


#   Supposed to make things nice with 'more' pager.... doesn't seem to matter!
$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = '\n';


###########################################################################
sub col_num_use 
{
    print '=' x 77 . "\n";
    print "$VERSION\n";
    print "\n";
    print "Usage: <infile> ['-' for stdin] [...options]\n";
    print "  <infile>   Text file (e.g. matrix of numbers)\n";
    print "  -rwb       Color scheme Red White Blue\n";
    print "  -ryc       Color scheme Red Yellow Cyan\n";
    print "  -rg # #    Range from # to #\n";
    print "  -lt #      Less than #\n";
    print "  -gt #      Greater than #\n";
    print "  -nr        Normal range: Color 0 to 1\n";
    print "  -n2        2-sided normal range: Color -1 to 1\n";
    print "  -ok        Only qualifying numbers colored\n";
    print "  -iz        Ignore zero (i.e. no color)\n";
    print "  -col # #   Columns # to # (Token-based count)\n";
    print "  -not       Invert col qualifications\n";
    print "  -all       Color all lines; Default ignores comment '#'\n";
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
    my $do_stdin = 0;
    my $help = 0;
    my $comargs = {
        'do_rwb'    => 0,
        'do_ryc'    => 0,
        'threshmap' => [],
        'th_lo'     => '',
        'th_hi'     => '',
        'do_nr'     => 0,
        'do_n2'     => 0,
        'do_iz'     => 0,
        'sub_cols'  => [],
        'do_ok'     => 0,
        'do_not'    => 0,
        'do_all'    => 0,
        'verb'      => 0,
    };
    my $options_ok = GetOptions (
        ''          => \$do_stdin,      # Empty string for only '-' as arg
        'help'      => \$help,
        'verb'      => \$comargs->{verbose},
        'rwb'       => \$comargs->{do_rwb},
        'ryc'       => \$comargs->{do_ryc},
        'rg=f{2}'   => $comargs->{threshmap},   # Ref to array
        'lt=f'      => \$comargs->{th_lo},
        'gt=f'      => \$comargs->{th_hi},
        'nr'        => \$comargs->{do_nr},
        'n2'        => \$comargs->{do_n2},
        'ok'        => \$comargs->{do_ok},
        'iz'        => \$comargs->{do_iz},
        'col=f{2}'  => $comargs->{sub_cols},
        'all'       => \$comargs->{do_all},
        'not'       => \$comargs->{do_not},
        );

    if ( ($help) || (!$options_ok) || ( (scalar @ARGV < 1)&&(!$do_stdin) ) ) {
        col_num_use();
        exit 1;
    }
    my $INFILE = \*STDIN;
    if (! $do_stdin ) {
        my $fname = shift @ARGV;
        open ($INFILE, '<', $fname ) or croak "Failed to open $fname\n", $!;
    }
    #
    #   Set up options and colors
    #
    set_up_options($comargs);
    my $colormap = set_up_colors($comargs);
    if ( ! $colormap ) {
        print "No colors = no fun!\n";
        exit 1;
    }
    report_colnum_settings($comargs, $colormap);

    #
    #   Process each line
    #
    while (my $line = <$INFILE> ) {
        # Comment
        if ( ($line =~ m/^\s*#/) && (! $comargs->{do_all}) ) {
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
sub set_up_options 
{
    my $comargs = shift @_;

    if ( $comargs->{th_lo} ) {
        $comargs->{threshmap}[0] = $comargs->{th_lo};
    }
    if ( $comargs->{th_hi} ) {
        $comargs->{threshmap}[1] = $comargs->{th_hi};
    }
    if ( $comargs->{do_nr} || $comargs->{do_n2} ) {
        $comargs->{threshmap}[0] = ( $comargs->{do_n2} ) ? -1.0 : 0.0;
        $comargs->{threshmap}[1] = 1.0;
    }
    # If we have a range, append 'not' flag
    if (scalar @{ $comargs->{sub_cols} } ) {
        push( @{ $comargs->{sub_cols} }, $comargs->{do_not});
    }
    return '';
}

###########################################################################
sub set_up_colors
{
    my $comargs = shift @_;
    my $colscheme = $COLSCHEME_DEF;
    if ( $comargs->{do_ryc} ) {
        $colscheme = $COLSCHEME_RYC;
    }
    elsif ( $comargs->{do_rwb} ) {
        $colscheme = $COLSCHEME_RWB;
    }
    if ( $comargs->{do_ok} ) {
        $colscheme = $COLSCHEME_QUAL;
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
    #   Specific color schemes
    #
    if ( $scheme == $COLSCHEME_QUAL ) {
        $colormap->{'Backgrd'} = $DEF_BACK_COLOR;
        $colormap->{'Match'} = $DEF_QUAL_COLOR;
    }
    elsif ( $scheme == $COLSCHEME_RYC ) {
        $colormap = {
        'Over'  => 'magenta', 
        'High'  => 'red', 
        'Mid'   => 'yellow', 
        'Low'   => 'cyan', 
        'Under' => 'blue', 
        };
    }
    elsif ( $scheme == $COLSCHEME_RWB) {
        $colormap = {
        'Over'  => 'yellow', 
        'High'  => 'red', 
        'Mid'   => 'white', 
        'Low'   => 'blue', 
        'Under' => 'green', 
        };
    }
    #
    #   Default
    #
    else {
        $colormap = {
        'High'  => 'red', 
        'Mid'   => 'yellow', 
        'Low'   => 'blue', 
        'Under' => 'white', 
        };
    }
    return $colormap;
}

###########################################################################
sub report_colnum_settings
{
    my ($comargs, $colormap) = @_;
    if ( $comargs->{verbose} ) {
        dump_num_thresh($comargs->{threshmap});
        print "# Color mapping:\n";
        foreach my $key ( sort keys %{$colormap} ) {
            my $story = $key . " => " . $colormap->{$key} . "\n";
            print "#  ";
            print_color_string($story, $colormap->{$key});
        }
    }
    return '';
}

###########################################################################
sub dump_num_thresh
{
    my $thresholds = shift @_;
    if (defined $thresholds->[0]) {
        print "# Low color threshold: $thresholds->[0]\n";
    } 
    if (defined $thresholds->[1]) {
        print "# High color threshold: $thresholds->[1]\n";
    } 
    return;
}

###########################################################################
#
#   Magic regex to match numbers (source?)
#
sub word_is_number 
{
    my $word = shift @_;
    my $isnum = 0; 

    if ( $word =~ m/^[-]?(?:[.]\d+|\d+(?:[.]\d*)?)$/ ) {
        $isnum ++;
    }
    return $isnum;
}

###########################################################################
#
#   Check if number is in range for coloring
#
sub is_col_in_range
{
    my $col = shift @_;
    my $sub_cols = shift @_;
    my $ok = 1;
    if ( scalar @{$sub_cols} ) {
        if (($col < $sub_cols->[0]) || ($col > $sub_cols->[1])) {
            $ok = 0;
        }
        $ok = ($sub_cols->[2]) ? !$ok : $ok;
    }
    return $ok;
}

###########################################################################
#
#   Return color based on number, thresholds and settings
#
sub color_for_val
{
    my ($num, $colormap, $comargs) = @_;
    my $threshmap = $comargs->{threshmap};
    my $curcol = $colormap->{'Mid'};
    my $qual = 0;
    #
    #   Both low and high thresholds
    #
    if ( defined($threshmap->[0]) && defined($threshmap->[1]) ) {
        if ($num < $threshmap->[0]) {
            $curcol = $colormap->{'Low'};
        }
        elsif ($num > $threshmap->[1]) {
            $curcol = $colormap->{'High'};
        }
        else {
            $qual++;
        }
    }
    #
    #   Low threshold only
    #
    elsif ( defined($threshmap->[0]) ) {
        if ($num <= $threshmap->[0]) {
            $curcol = $colormap->{'Low'};
            $qual++;
        }
    }
    #
    #   High threshold only
    #
    elsif ( defined($threshmap->[1]) ) {
        if ($num >= $threshmap->[1]) {
            $curcol = $colormap->{'High'};
            $qual++;
        }
    }
    #   No thresholds, so all qualify
    else {
        $qual++;
    }
    #
    #   If qualified numbers only, 
    #
    if ( $comargs->{do_ok} ) {
        $curcol = $qual ? $colormap->{'Match'} : $colormap->{'Backgrd'};
    }
    #
    #   Ignore zeros
    #
    if ( $comargs->{do_iz} && ($num == 0.0) ) {
        # $curcol = $colormap->{'Backgrd'};
        $curcol = $DEF_BACK_COLOR;
    }
    return $curcol;
}

###########################################################################
#
#   Dump out one line with colored numbers
#
sub dump_color_line
{
    my ($line, $colormap, $comargs) = @_;
    my $char_state = 'bold';
    #
    #   Process word at a time; split_string returns list of actual words
    #       but also spaces in between the words.
    #
    my $tokens = split_string($line);
    my $col = 0;
    foreach my $word ( @{$tokens} ) {
        if ( $word =~ m/\S/ ) {
            $col++;
        }
        my $col_ok = is_col_in_range($col, $comargs->{sub_cols});
        if ( word_is_number($word) && $col_ok ) {
            my $curcol = color_for_val($word, $colormap, $comargs);
            print color($char_state, $curcol);
            print $word;
        }
        else {
            ##print color('reset');
            set_bold_white();
            print $word;
        }
    }
    #print color('reset');
    set_bold_white();
}

###########################################################################
sub print_color_string
{
    my $word = shift @_;
    my $color = shift @_;
    my $char_state = 'bold';
    print color($char_state, $color);
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

