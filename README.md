comline_color_seq_num
=====================
5/27/18 RTK

Command line tools to (ANSI) colorize DNA sequences (bioinformatics) or numbers (data analysis) found within text.

    color_seq.pl        Colors DNA sequence characters

    color_nums.pl       Color numbers


=====================
Background and overview

The scripts color_seq.pl and color_nums.pl are simple command line filters intended to colorize specific value-associated “words” contained within simple ASCII text. This is useful to highlight specific values for quick value identification and pattern visualization. Both tools take text from a file or standard input then output this with ANSI escape sequences interjected to color specific characters in a terminal display. Both tools also accept various command line options to allow user control over character or token selection and color choice.

The document "comline_color_seq_num_use.pdf" shows colored screenshots corresponding to example usage of both scripts.

Example test-case files include a fasta format sequence file ("examp.fas") and several number-containing files (*.mat)


=====================
Dependencies

These perl modules are used:

    Term::ANSIColor         For color encoding
    Getopt::Long;           For command line processing
    Readonly;               For constants
    Carp;


=====================
Limitations / To do

color_seq.pl

> Lines are considered independently; Windows of base type cannot wrap for multi-line sequence formats like fasta.

color_nums.pl

> Would be nice to have more than three colors (though given the ASNI pallete, what can one expect!)

