#!/usr/bin/perl -w
#   Simple text coloring of columns
#   Ryan Koehler 1/14/15; Modified from color_nums.pl
#

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
use Readonly;
use Carp;
use RTKUtil     qw(split_string);

Readonly my $VERSION => "color_cols.pl V0.1; RTK 1/14/15";

#   Constants for coloring scheme
Readonly my $COLSCHEME_DEF  => 0;
Readonly my $COLSCHEME_3C   => 1;
Readonly my $COLSCHEME_5C   => 2;

Readonly my $DEF_QUAL_COLOR => 'red';
Readonly my $DEF_BACK_COLOR => 'white';

Readonly my $DEF_MSTEP      => 2;


#   Supposed to make things nice with 'more' pager.... doesn't seem to matter!
$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = '\n';


###########################################################################
sub col_cols_use 
{
    print '=' x 77 . "\n";
    print "$VERSION\n";
    print "\n";
    print "Usage: <infile> ['-' for stdin] [...options]\n";
    print "  <infile>   Text file (e.g. data with 'word' tokens)\n";
    print "  -m #       Mark col # (Note: 1-based index on tokens)\n";
    print "  -s #       Step; Mark every #'th col\n";
    print "  -col # #   Limit coloring to cols # to #\n";
    print "  -not       Invert col qualifications\n";
    print "  -5c        Five color scheme: White Yellow Green Red Cyan\n";
    print "  -159c      One-five-nine color scheme: 1, 5 and 9 (repeated)\n";
    print "  -all       Color all lines; Default ignores comment '#'\n";
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
        'mstep'     => $DEF_MSTEP,
        'cmark'     => 0,
        'do_5c'     => 0,
        'do_159c'   => 0,
        'do_all'    => 0,
        'do_not'    => 0,
        'sub_cols'  => [0,1000000],
    };
    my $options_ok = GetOptions (
        ''          => \$do_stdin,      # Empty string for only '-' as arg
        'help'      => \$help,
        's=i'       => \$comargs->{mstep},
        'm=i'       => \$comargs->{cmark},
        '5c'        => \$comargs->{do_5c},
        '159c'      => \$comargs->{do_159c},
        'all'       => \$comargs->{do_all},
        'col=f{2}'  => $comargs->{sub_cols},
        'not'       => \$comargs->{do_not},
        );
    if ( ($help) || (!$options_ok) || ( (scalar @ARGV < 1)&&(!$do_stdin) ) ) {
        col_cols_use();
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
    if ( ! set_up_options($comargs)) {
        print "Sham with parsed options!\n";
        exit 1;
    }
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
    # If marking one col, put this value into the range structure
    if ($comargs->{cmark} > 0) {
        @{ $comargs->{sub_cols}}[0] = $comargs->{cmark};
        @{ $comargs->{sub_cols}}[1] = $comargs->{cmark} + 1;
    }
    # If we have a range, append 'not' flag to range
    push( @{ $comargs->{sub_cols} }, $comargs->{do_not});
    # Make mstep at least default value 
    if ( $comargs->{mstep} < 1 ) {
        $comargs->{mstep} = $DEF_MSTEP;
    }
    return 1;
}

###########################################################################
sub set_up_colors
{
    my $comargs = shift @_;
    my $colscheme = $COLSCHEME_DEF;
    if ( $comargs->{do_5c} ) {
        $colscheme = $COLSCHEME_5C;
    }
    elsif ( $comargs->{do_159c} ) {
        $colscheme = $COLSCHEME_3C;
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
    my $colormap = {
        'Backgrd' => $DEF_BACK_COLOR,
        'Match' => $DEF_QUAL_COLOR,
    # sham ... should be scheme-specific ???
        '0'     => 'red', 
        '1'     => 'yellow', 
        '2'     => 'green', 
        '3'     => 'cyan', 
        '4'     => 'magenta', 
        'low'   => 'red', 
        'mid'   => 'cyan', 
        'high'  => 'green', 
        'Backgrd' => $DEF_BACK_COLOR,
        'Match' => $DEF_QUAL_COLOR,
    };
    return $colormap;
}

###########################################################################
#
#   Would this ever be useful???
#
sub report_colnum_settings
{
    my ($comargs, $colormap) = @_;
    return '';
}

###########################################################################
#
#   Check if column is in range for coloring
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
#   Return color based on col number and settings
#
sub color_for_col
{
    my ($col, $colormap, $comargs) = @_;

    my $curcol = $colormap->{'Backgrd'};
    #
    #   Explicit mark
    #
    if ($comargs->{cmark} > 0) {
        $curcol = ($comargs->{cmark} == $col) ? $colormap->{'Match'} : $colormap->{'Backgrd'} ;
    }
    #
    #   Five color case?
    #
    elsif ( $comargs->{do_5c} ) {
        my $cind = ($col - 1) % 5;
        $curcol = $colormap->{$cind};
    }
    #
    #   159 three color case?
    #
    elsif ( $comargs->{do_159c} ) {
        my $cind = ($col - 1) % 10;
        if ($cind == 0) {
            $curcol = $colormap->{'low'};
        }
        elsif ($cind == 4) {
            $curcol = $colormap->{'mid'};
        }
        elsif ($cind == 9) {
            $curcol = $colormap->{'high'};
        }
    }
    #
    #   Simple odd / even
    #
    else {
        my $coff = $col % $comargs->{mstep};
        $curcol = ($coff == 1) ? $colormap->{'Match'} : $colormap->{'Backgrd'} ;
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
        if ( $col_ok ) {
            my $curcol = color_for_col($col, $colormap, $comargs);
            print color($char_state, $curcol);
            print $word;
        }
        else {
            print color('reset');
            print $word;
        }
    }
    print color('reset');
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

