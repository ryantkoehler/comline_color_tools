package RTKUtil;
#   Misc util functions
#   RTK 3/10/10   
#
#   7/15/11 RTK; Add SlurpFile
#   3/12/14 RTK; Update, add SplitString
#   

use strict;
use warnings;

#   Older sham (correct?)
# To share functions from this module, use Exporter
#   Sub names listed in EXPORT are always exported (i.e. use Module;)
#   Subs in EXPORT_OK only exported when asked (i.e. use Module qw(sub_name);)
#use Exporter;
#use vars qw(@ISA @EXPORT_OK @EXPORT);
#@ISA = qw(Exporter);
#@EXPORT = qw(PrintBannerLine SlurpFile RunAndParse);
#@EXPORT_OK = qw();
#   New sham; 3/14/14
use Exporter qw(import);
our @EXPORT_OK = qw(print_banner_line slurp_file split_string);


##############################################################################
#
#   Print a banner line
#   If any first arg is passed, the banner has this up front
#   If a second arg is passed, this is treated as a file handle
#
sub print_banner_line 
{
    my $sham = ( (scalar @_) > 0) ? shift @_ : '';
    my $outfile = ( (scalar @_) > 0) ? shift @_ : *STDOUT;
    my $shamlen = 78 - length($sham);
    print {$outfile} $sham . "=" x $shamlen . "\n";
}

##############################################################################
#
#   Open and slurp file
#   If second argument, failures are fatal and we die here
#   Returns list of strings (each line) with file contents
#
sub slurp_file 
{
    my $fname = shift @_;
    my $fatal = ( (scalar @_) > 0) ? 1 : 0;
    my @fcon = ();
    if ( open (my $INFILE , '<', $fname ) ) {
        while ( <$INFILE> ) {
            push @fcon, $_ ;
        }
        close ( $INFILE );
    }
    elsif ( $fatal ) {
        die "Failed to open $fname\n", $!;
    }
    return @fcon;
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

######################
#
#   Package OK
#
1;

