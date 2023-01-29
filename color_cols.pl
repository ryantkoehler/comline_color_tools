#!/usr/bin/env perl 
# #!/usr/bin/env perl -w
#   Simple text coloring of columns
#   Ryan Koehler 1/14/15; Modified from color_nums.pl
#   3/21/15 RTK; V0.2; Add -2c and default to -10c
#   4/28/15 RTK; V0.3; Add -tab separation option
#   9/28/15 RTK; V0.31; Fix bug with -s and -5c; Update on github
#   7/7/16 RTK; V0.32; Change -col to -rg for consistency; Update so 5 5 = col5
#   8/23/16 RTK; V0.4; Add -row -o -fc -bc -sep options;
#       Also add 'config no_ignore_case' for Getopt, propagate comargs into 
#       all functions, replace RTKutil(split_string)
#   8/30/16 RTK; V0.41; Add -prd -pld ('comargs' should be a class ...)
#   9/16/16 RTK; V0.5; Add -10r and make this default; Add -rr and change
#       -rg to -cr; Add -iv; Split -not into -nc and -nr
#   11/9/16 RTK; V0.51; Fix off-by-one for column coloring
#   11/18/16 RTK; V0.52; Fix sham with leading spaces for column coloring
#   2/1/17 RTK; V0.53; Add -g 
#   10/7/17 RTK; V0.54; Fix range and column background colors (reset to bkg)
#   12/13/17 RTK; V0.55; Add -ic
#   12/20/19 V0.6 RTK; Add explicit split_string
#   2023-01-28 RTK V0.7; Remove Readonly dependence
#

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);
use Term::ANSIColor;
use Carp;

my $VERSION = "color_cols.pl V0.7; RTK 2023-01-28";

my $COLSCHEME_2    = '2c';
my $COLSCHEME_5    = '5c';
my $COLSCHEME_10C  = '10c';
my $COLSCHEME_10R  = '10r';

# Defaults
my $DEF_FG_COLOR = 'red';
my $DEF_BG_COLOR = 'white';
my $DEF_SEP_STR = '\s';

#   Supposed to make things nice with 'more' pager.... doesn't seem to matter!
$Term::ANSIColor::AUTORESET = 1;
$Term::ANSIColor::EACHLINE = '\n';


###########################################################################
sub col_cols_use 
{
    my $comargs = shift @_;

    print '=' x 77 . "\n";
    print "$VERSION\n";
    print "\n";
    print "Usage: <infile> ['-' for stdin] [...options]\n";
    print "  <infile>   Text file (e.g. data with 'word' tokens)\n";
    print "  -m #       Mark col # (1-based index on tokens)\n";
    print "  -s #       Step; Mark every #'th col (starting from 0)\n";
    print "  -o #       Offset for starting steps (default 0)\n";
    print "  -g #       Group columns / rows # at a time (default 1)\n";
    print "  -cr # #    Colums in range # to # colored (1-based)\n";
    print "  -nc        Invert column range qualifications\n";
    print "  -rr # #    Rows in range # to # colored (1-based)\n";
    print "  -nr        Invert row range qualifications\n";
    print "  -tab       Separate input columns by tab (default is space)\n";
    print "  -sep X     Separate input columns by X string\n";
    print "  -2c        Two color scheme:    Cycle ";
    print_color_scheme_nums($comargs, $COLSCHEME_2, 10);
    print "  -5c        Five color scheme:   Cycle ";
    print_color_scheme_nums($comargs, $COLSCHEME_5, 10);
    print "  -10c       Ten color scheme:    Cycle ";
    print_color_scheme_nums($comargs, $COLSCHEME_10C, 10);
    print "  -10r       Ten rainbow scheme:  Cycle ";
    print_color_scheme_nums($comargs, $COLSCHEME_10R, 10);
    print "  -fg X      Set foreground color to X [RYGBCMW] (default $DEF_FG_COLOR)\n";
    print "  -bg X      Set background color to X [RYGBCMW] (default $DEF_BG_COLOR)\n";
    print "  -iv        Invert foreground / background (i.e. for -mark or -step)\n";
    print "  -all       Color all lines; Default ignores comment '#'\n";
    print "  -ic        Ignore (leading) comment '#' for col counts with -all\n";
    print "  -row       Apply coloring to *Rows* not columns\n";
    print "  -prd       Previous row differences (per token)\n";
    print "  -pld       Previous line differences (per char)\n";
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
        'm_off'     => 0,
        'group'     => 0,
        'cmark'     => 0,
        'do_2c'     => 0,
        'do_5c'     => 0,
        'do_10c'    => 0,       
        'do_10r'    => 0,       
        'do_all'    => 0,
        'do_ic'     => 0,
        'sub_cols'  => [],
        'sub_rows'  => [],
        'do_nc'     => 0,
        'do_nr'     => 0,
        'do_iv'     => 0,
        'do_tab'    => 0,
        'sep_str'   => $DEF_SEP_STR,
        'fg_col'    => $DEF_FG_COLOR,
        'bg_col'    => $DEF_BG_COLOR,
        'do_row'    => 0,
        'do_prd'    => 0,
        'do_pld'    => 0,
        'colormap'  => '',              # Colormap
        'prdline'   => '',              # Previous line for prd
        'prdtoks'   => '',              # Previous line token list for prd
    };
    my $options_ok = GetOptions (
        ''          => \$do_stdin,      # Empty string for only '-' as arg
        'help'      => \$help,
        's=i'       => \$comargs->{mstep},
        'o=i'       => \$comargs->{m_off},
        'g=i'       => \$comargs->{group},
        'm=i'       => \$comargs->{cmark},
        '2c'        => \$comargs->{do_2c},
        '5c'        => \$comargs->{do_5c},
        '10c'       => \$comargs->{do_10c},
        '10r'       => \$comargs->{do_10r},
        'all'       => \$comargs->{do_all},
        'ic'        => \$comargs->{do_ic},
        'cr=i{2}'   => $comargs->{sub_cols},
        'rr=i{2}'   => $comargs->{sub_rows},
        'nc'        => \$comargs->{do_nc},
        'nr'        => \$comargs->{do_nr},
        'iv'        => \$comargs->{do_iv},
        'tab'       => \$comargs->{do_tab},
        'fg=s'      => \$comargs->{fg_col},
        'bg=s'      => \$comargs->{bg_col},
        'sep=s'     => \$comargs->{sep_str},
        'row'       => \$comargs->{do_row},
        'prd'       => \$comargs->{do_prd},
        'pld'       => \$comargs->{do_pld},
        );
    if ( ($help) || (!$options_ok) || ( (scalar @ARGV < 1)&&(!$do_stdin) ) ) {
        col_cols_use($comargs);
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
    if ( ! set_up_colors($comargs) ) {
        print "No colors = no fun!\n";
        exit 1;
    }
    report_colnum_settings($comargs);
    #
    #   Process each line
    #
    my $lnum = 0;
    while (my $line = <$INFILE> ) {
        # Comment
        if ( ($line =~ m/^\s*#/) && (! $comargs->{do_all}) ) {
            print $line;
        }
        else {
            $lnum ++;
            dump_color_line($comargs, $line, $lnum);
        }
    }
    #   Clean up 
    close ($INFILE);
    print color('reset');
}

###########################################################################
#   
#   Make options work together
#   
sub set_up_options 
{
    my $comargs = shift @_;

    # If nothing set in range
    if (scalar @{ $comargs->{sub_cols}} < 2) {                                                                   
        $comargs->{sub_cols} = '';
    }       
    if (scalar @{ $comargs->{sub_rows}} < 2) {                                                                   
        $comargs->{sub_rows} = '';
    }       

    # If -2c, -5c, -10c or specific mark, turn off -10r coloring; Else on by default
    #   (This dictates default color)
    if ( ($comargs->{cmark} > 0) || $comargs->{do_2c} || $comargs->{do_5c} || $comargs->{do_10c} ) {
          $comargs->{do_10r} = 0;
    }
    else {
        $comargs->{do_10r} = 1;
    }

    # If mstep, turn off 5 and 10 color; Else default to 2
    if ( $comargs->{mstep} > 0 ) {
        $comargs->{do_10c} = 0;
        $comargs->{do_10r} = 0;
        $comargs->{do_5c} = 0;
    }
    else {
        $comargs->{mstep} = 2;
    }

    # Set separater string
    if ( $comargs->{do_tab} ) {
        $comargs->{sep_str} = '\t';
    }

    # If prl, also set prd (this is default prev-row-case)
    if ( $comargs->{do_pld} ) {
        $comargs->{do_prd} = 1;
    }

    # Grouping must be 1 or more 
    if ( $comargs->{group} < 1) {
        $comargs->{group} = 1;
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

    if ( $comargs->{do_5c} ) {
        $comargs->{colormap} = get_scheme_colormap($comargs, $COLSCHEME_5);
    }
    elsif ( $comargs->{do_10r} ) {
        $comargs->{colormap} = get_scheme_colormap($comargs, $COLSCHEME_10R);
    }
    elsif ( $comargs->{do_10c} ) {
        $comargs->{colormap} = get_scheme_colormap($comargs, $COLSCHEME_10C);
    }
    else {
        $comargs->{colormap} = get_scheme_colormap($comargs, $COLSCHEME_2);
    }
    return $comargs->{colormap};
}

###########################################################################
#
#   Parse color single / first letter RYGBCMW into ansi color name
#
sub parse_color_name
{
    my $c = uc shift @_;

    my $color = '';
    if ( $c =~ m/^R/ ) {
        $color = 'red';
    }
    elsif ( $c =~ m/^Y/ ) {
        $color = 'yellow';
    }
    elsif ( $c =~ m/^G/ ) {
        $color = 'green';
    }
    elsif ( $c =~ m/^C/ ) {
        $color = 'cyan';
    }
    elsif ( $c =~ m/^B/ ) {
        $color = 'blue';
    }
    elsif ( $c =~ m/^M/ ) {
        $color = 'magenta';
    }
    elsif ( $c =~ m/^W/ ) {
        $color = 'white';
    }
    return $color;
}

###########################################################################
#
#   Create and fill color mapping hash
#   Allowed colors: "blue","magenta","red","yellow","green","cyan","white","black"
#
sub get_scheme_colormap
{
    my ($comargs, $sch) = @_;

    # Parse fore / back colors
    my $fg_color = parse_color_name($comargs->{fg_col});
    my $bg_color = parse_color_name($comargs->{bg_col});
    if ((! $fg_color) || (! $bg_color)) {
        print "Problem parsing For / Back colors: $comargs->{fg_col}, $comargs->{bg_col}\n";
        return '';
    }
    # Init minimal color map
    my $colormap = {
        'Backgrd' => $bg_color,
        'Match' => $fg_color,
        '0' => $bg_color,
        '1' => $fg_color,
    };
    # Specific schemes may need others / more ....
    # 5 color case
    if ($sch eq $COLSCHEME_5) {
        $colormap->{'0'} = 'red';
        $colormap->{'1'} = 'yellow';
        $colormap->{'2'} = 'green';
        $colormap->{'3'} = 'cyan';
        $colormap->{'4'} = 'magenta';
    }
    # 10 color case, rainbow
    if ($sch eq $COLSCHEME_10R) {
        $colormap->{'0'} = 'red';
        $colormap->{'1'} = 'white';
        $colormap->{'2'} = 'yellow';
        $colormap->{'3'} = 'white';
        $colormap->{'4'} = 'green';
        $colormap->{'5'} = 'white';
        $colormap->{'6'} = 'cyan';
        $colormap->{'7'} = 'white';
        $colormap->{'8'} = 'magenta';
        $colormap->{'9'} = 'white';
    }
    # 10 color case, default
    if ($sch eq $COLSCHEME_10C) {
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
    my $comargs = shift @_;

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
    my ($comargs, $col) = @_;

    my $ok = 1;
    my $sub_cols = $comargs->{sub_cols};
    # Only check range if there is one
    if ( $sub_cols ) {
        if (($col < $sub_cols->[0]) || ($col > $sub_cols->[1])) {
            $ok = 0;
        }
    }
    $ok = ($comargs->{do_nc}) ? !$ok : $ok; 
    return $ok;
}

###########################################################################
#
#   Check if there is -no- column range specified; True if none
#
sub no_col_range
{
    my ($comargs) = @_;
    my $ok = ( $comargs->{sub_cols} ) ? 0 : 1;
    return $ok;
}

###########################################################################
sub is_row_in_range
{
    my ($comargs, $row) = @_;

    my $ok = 1;
    my $sub_rows = $comargs->{sub_rows};
    # Only check range if there is one
    if ( $sub_rows) {
        if (($row < $sub_rows->[0]) || ($row > $sub_rows->[1])) {
            $ok = 0;
        }
    }
    $ok = ($comargs->{do_nr}) ? !$ok : $ok; 
    return $ok;
}

###########################################################################
#
#   Return color based on col number and settings
#
sub color_for_col
{
    my ($comargs, $col) = @_;

    my ($cind, $coff);
    my $colormap = $comargs->{colormap};
    my ($fgcolor, $bkcolor) = for_back_colors($comargs);
    my $curcol = $colormap->{'Backgrd'};

    #   Adjust given column number to group-based col ... cols are 1-based
    $col = int(($col + $comargs->{group} -1) / $comargs->{group});

    #
    #   Explicit mark
    #
    if ($comargs->{cmark} > 0) {
        if ($comargs->{do_iv}) {
            $curcol = ($comargs->{cmark} != $col) ? $fgcolor : $bkcolor;
        }
        else {
            $curcol = ($comargs->{cmark} == $col) ? $fgcolor : $bkcolor;
        }
    }
    #
    #   Five color case?
    #
    elsif ( $comargs->{do_5c} ) {
        $cind = ($col - 1) % 5;
        $curcol = $colormap->{$cind};
    }
    #
    #   10color cases?
    #
    elsif (($comargs->{do_10c}) || ($comargs->{do_10r})) {
        $cind = ($col - 1) % 10;
        if ( exists $colormap->{$cind} ) {
            $curcol = $colormap->{$cind};
        }
        else {
            $curcol = $colormap->{'Backgrd'};
        }
    }
    #
    #   Simple on / off; col adjusted by offset; color by mstep
    #
    else {
        $coff = ($col - $comargs->{m_off} + 1) % $comargs->{mstep};
        if ($comargs->{do_iv}) {
            $curcol = ($coff != 1) ? $fgcolor : $bkcolor;
        }
        else {
            $curcol = ($coff == 1) ? $fgcolor : $bkcolor;
        }
    }
    return $curcol;
}

###########################################################################
sub for_back_colors
{
    my $comargs = shift @_;

    my $colormap = $comargs->{colormap};
    return ( $colormap->{'Match'}, $colormap->{'Backgrd'} );
}

###########################################################################
sub reset_back_color
{
    my $comargs = shift @_;

    # Reset to terminal default
    #print color('reset');

    # Reset to our default; Bold with specific background
    my $char_state = 'bold';
    my $colormap = $comargs->{colormap};
    print color($char_state, $colormap->{'Backgrd'});
}

###########################################################################
#   
#   Handle current line; Call sub funcitons, passing args through
#
sub dump_color_line
{
    my ($comargs, $line, $lnum) = @_;

    # Previous-row-dif case
    if ( $comargs->{do_prd} ) {
        handle_prd_row_line(@_);
    }
    else {
        # Get row range status and flag if no column range specified;
        my $row_ok = is_row_in_range($comargs, $lnum);
        my $no_cr = no_col_range($comargs);
        if ($row_ok || $no_cr) {
            # Only dump whole row if row OK and no column range
            if ( $comargs->{do_row} && $no_cr) {
                dump_color_row_line(@_);
            }
            else {
                dump_color_col_line(@_);
            }
        }
        else {
            reset_back_color($comargs);
            print $line;
        }
    }
}

###########################################################################
#
#   Dump one line with previous row diffs colored; Keep row for next time
#
sub handle_prd_row_line
{
    my ($comargs, $line, $lnum) = @_;

    my ($fgcolor, $bkcolor) = for_back_colors($comargs);
    if ( $comargs->{do_iv} ) {
        ($fgcolor, $bkcolor) = ($bkcolor, $fgcolor);
    }
    # Split up line; per char or tokens
    my @tokens = '';
    if ( $comargs->{do_pld} ) {
        @tokens = split(//,$line);
    }
    else {
        my $tokens = tokens_for_line($comargs, $line);
        @tokens = @{ $tokens };
    }

    # Have previous line to compare?
    if($comargs->{prdline}) {
        # Split up line; per char or tokens
        if ( $comargs->{do_pld} ) {
            @tokens = split(//,$line);
        }
        else {
            my $tokens = tokens_for_line($comargs, $line);
            @tokens = @{ $tokens };
        }

        # Loop over current collection of tokens, comparing to previous
        my @ptokens = @{ $comargs->{prdtoks} };
        my $pdif = 0;
        my $color = 0;
        for ( my $i = 0; $i < scalar @tokens; $i++ ) {
            $color = (($i < scalar @ptokens) && ($tokens[$i] ne $ptokens[$i])) ? $fgcolor : $bkcolor;
            print_color_string($comargs, $tokens[$i], $color);
        }
    }
    #   First line
    else {
        print_color_string($comargs, $line, $bkcolor);
    }
    # Save for next line
    $comargs->{prdline} = $line;
    $comargs->{prdtoks} = \@tokens;
}

###########################################################################
#
#   Dump one line in color or not based on line number
#
sub dump_color_row_line
{
    my ($comargs, $line, $lnum) = @_;

    my $char_state = 'bold';
    # When dumping by row, line ~= column
    my $color = color_for_col($comargs, $lnum);
    print color($char_state, $color);
    print $line;
    reset_back_color($comargs);
}

###########################################################################
#
#   Dump out one line with colored columns (words)
#
sub dump_color_col_line
{
    my ($comargs, $line, $lnum) = @_;

    my $char_state = 'bold';
    my $tokens = tokens_for_line($comargs, $line);
    # Start at col 1; Increment on separators _after_ first _print_ col
    my $col = 1;
    my $pw = 0;
    # Process each 'word'; 
    #   List of tokens has (char) words AND (separator) spaces
    foreach my $word ( @{$tokens} ) {
        # Printable?
        if ( $word =~ m/^\S+$/ ) {
            # Ignoring leading comment? 
            #   Increment print count if not ignoring, not comment
            if ((! $comargs->{do_ic}) || ($word ne '#')) {
                $pw++;
            }
        }
        # Separator after printable-word, increase col count
        if (( $word =~ m/$comargs->{sep_str}/ ) && ( $pw > 0 )) {
            $col++;
        }
        my $col_ok = is_col_in_range($comargs, $col);
        if ( $col_ok ) {
            my $curcol = color_for_col($comargs, $col);
            print color($char_state, $curcol);
            print $word;
        }
        else {
            reset_back_color($comargs);
            print $word;
        }
    }
    reset_back_color($comargs);
}

###########################################################################
#
#   Return list of tokens and between-tokens
#
sub tokens_for_line
{
    my ($comargs, $line) = @_;

    #   Could use this?
    # Split with () around separater, keeps separater 
    # my @toks = split(/($comargs->{sep_str})/,$line);

    return split_string($line, $comargs->{sep_str});
}

###########################################################################
sub print_color_scheme_nums
{
    my ($comargs, $sch, $max) = @_;

    my $num = 0;
    my $colormap = get_scheme_colormap($comargs, $sch);
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
    print "\n";
    set_bold_white();
    return $num;
}

###########################################################################
sub print_color_string
{
    my ($comargs, $word, $color) = @_;

    my $char_state = 'bold';
    print color($char_state, $color);
    print $word;
    reset_back_color($comargs);
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

