package DnaString;
#   DNA sequence utilities
#   RTK 1/4/11
#
#   3/12/14 RTK; Change and standardize names (module, functions)
#

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(
                    dna_base_degen
                    dna_iub_match
                    seq_rev_comp 
                    get_seq_in_string 
                    string_dna_chars 
                    frac_string_dna_chars
                    );


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

