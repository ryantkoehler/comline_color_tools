#!/usr/bin/perl -w
#   Simple text coloring of columns
#   Ryan Koehler 1/14/15; Modified from color_nums.pl
#   3/21/15 RTK; V0.2; Add -2c and default to -10c
#   4/28/15 RTK; V0.3; Add -tab separation option
#   9/28/15 RTK; V0.31; Fix bug with -s and -5c; Update on github
#

use strict;
use warnings;
use Getopt::Long;
use Term::ANSIColor;
use Readonly;
use Carp;
use RTKUtil     qw(split_string);

Readonly my $VERSION => "color_cols.pl V0.31; RTK 9/28/15";

Readonly my $COLSCHEME_2    => '2c';
Readonly my $COLSCHEME_5    => '5c';
Readonly my $COLSCHEME_10   => '10c';

# Defaults
Readonly my $DEF_QUAL_COLOR => 'red';
Readonly my $DEF_BACK_COLOR => 'white';


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
    print "  -tab       Separate columns by tab (default is space)\n";
    print "  -not       Invert col qualifications\n";
    print "  -2c        Two color scheme:  Cycle ";
    print_color_scheme_nums($COLSCHEME_2, 10);
    print "  -5c        Five color scheme: Cycle ";
    print_color_scheme_nums($COLSCHEME_5, 10);
    print "  -10c       Ten color scheme:  Cycle ";
    print_color_scheme_nums($COLSCHEME_10, 10);
    print "  -all       Color all lines; Default ignores comment '#'\n";
    print '=' x 77 . "\n";
    print "\n";
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
        'mstep'     => 0,
        'cmark'     => 0,
        'do_2c'     => 0,
        'do_5c'     => 0,
        'do_10c'    => 0,       
        'do_all'    => 0,
        'do_not'    => 0,
        'do_tab'    => 0,
        'sub_cols'  => [],
    };
    my $options_ok = GetOptions (
        ''          => \$do_stdin,      # Empty string for only '-' as arg
        'help'      => \$help,
        's=i'       => \$comargs->{mstep},
        'm=i'       => \$comargs->{cmark},
        '2c'        => \$comargs->{do_2c},     
        '5c'        => \$comargs->{do_5c},
        '10c'       => \$comargs->{do_10c},
        'all'       => \$comargs->{do_all},
        'col=i{2}'  => $comargs->{sub_cols},
        'not'       => \$comargs->{do_not},
        'tab'       => \$comargs->{do_tab},
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
#   
#   Make options work together
#   
sub set_up_options 
{
    my $comargs = shift @_;

    # Initialize range structure if nothing there
    if (scalar @{ $comargs->{sub_cols}} < 2) {
        @{ $comargs->{sub_cols}}[0] = 0;
        @{ $comargs->{sub_cols}}[1] = 100000;
    }
    # Append 'not' flag to range
    push( @{ $comargs->{sub_cols} }, $comargs->{do_not});

    # If marking one col, put this value into the range structure
    if ($comargs->{cmark} > 0) {
        @{ $comargs->{sub_cols}}[0] = $comargs->{cmark};
        @{ $comargs->{sub_cols}}[1] = $comargs->{cmark} + 1;
    }

    # If -2c or -5c or specific mark, turn off -10c coloring; Else on by default
    if ( ($comargs->{cmark} > 0) || $comargs->{do_2c} || $comargs->{do_5c} ) {
          $comargs->{do_10c} = 0;
    }
    else {
        $comargs->{do_10c} = 1;
    }

    # If mstep, turn off 5 and 10 color; Else default to 2
    if ( $comargs->{mstep} > 0 ) {
        $comargs->{do_10c} = 0;
        $comargs->{do_5c} = 0;
    }
    else {
        $comargs->{mstep} = 2;
    }

    return 1;
}

###########################################################################
#
#   Get working colormap based on command args
#
sub set_up_colors
{
    my $comargs = shift @_;
    my $colormap = '';
    if ( $comargs->{do_5c} ) {
        $colormap = get_scheme_colormap($COLSCHEME_5);
    }
    elsif ( $comargs->{do_10c} ) {
        $colormap = get_scheme_colormap($COLSCHEME_10);
    }
    else {
        $colormap = get_scheme_colormap($COLSCHEME_2);
    }
    return $colormap;
}

###########################################################################
#
#   Create and fill color mapping hash
#   Allowed colors: "blue","magenta","red","yellow","green","cyan","white","black"
#
sub get_scheme_colormap
{
    my $sch = shift @_;

    # Init minimal color map
    my $colormap = {
        'Backgrd' => $DEF_BACK_COLOR,
        'Match' => $DEF_QUAL_COLOR,
        '0' => 'red',
        '1' => 'white',
    };
    # Specific schemes may need more ....
    # 5 color case
    if ($sch eq $COLSCHEME_5) {
        $colormap->{'0'} = 'red';
        $colormap->{'1'} = 'yellow';
        $colormap->{'2'} = 'green';
        $colormap->{'3'} = 'cyan';
        $colormap->{'4'} = 'magenta';
    }
    # 10 color case
    if ($sch eq $COLSCHEME_10) {
        $colormap->{'0'} = 'red';
        $colormap->{'1'} = 'white';
        $colormap->{'2'} = 'yellow';
        $colormap->{'3'} = 'white';
        $colormap->{'4'} = 'cyan';
        $colormap->{'5'} = 'white';
        $colormap->{'6'} = 'yellow';
        $colormap->{'7'} = 'white';
        $colormap->{'8'} = 'green';
        $colormap->{'9'} = 'white';
    }
    return $colormap;
}

###########################################################################
#
#   Would this ever be useful???
#
sub report_colnum_settings
{
    my ($comargs, $colormap) = @_;

    # TODO; debug?
    #use Data::Dumper;
    #print Dumper($comargs);

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
    # Only check range if there is one
    if ( $sub_cols ) {
        if (($col < $sub_cols->[0]) || ($col > $sub_cols->[1])) {
            $ok = 0;
        }
        $ok = ($sub_cols->[2] > 0) ? !$ok : $ok;
    }
# TODO debug
#print "|$col=$ok|";
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

#        if ( exists $colormap->{$cind} ) {
#        }
#        else {
#print "xxx $cind $curcol"
#        }

    }
    #
    #   10color case?
    #
    elsif ( $comargs->{do_10c} ) {
        my $cind = ($col - 1) % 10;
        if ( exists $colormap->{$cind} ) {
            $curcol = $colormap->{$cind};
        }
        else {
            $curcol = $colormap->{'Backgrd'};
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
    my $tokens = '';
    my $col = 0;
    #
    #   Process word at a time; split_string returns list of actual words
    #       but also spaces in between the words.
    #
# TODO test this ... does it do anything different???
    if ( $comargs->{do_tab} ) {
        $tokens = split_string($line, '\t');
    }
    else {
        $tokens = split_string($line);
    }
    #   Loop over words
    foreach my $word ( @{$tokens} ) {
        if ( $word =~ m/\S/ ) {
            $col++;
        }
        my $col_ok = is_col_in_range($col, $comargs->{sub_cols});
        if ( $col_ok ) {
# TODO debug
#print ".";
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
sub print_color_scheme_nums
{
    my $sch = shift @_;
    my $max = shift @_;

    my $num = 0;
    my $colormap = get_scheme_colormap($sch);
    if ($colormap) {
        my $char_state = 'bold';
        while ($num < $max) {
            if ( exists $colormap->{$num} ) {
                my $curcol = $colormap->{$num};
                print color($char_state, $curcol);
                $num++;
                print "$num ";
            }
            else {
                last;
            }
        }
    }
    print color('reset');
    print "\n";
    return $num;
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

