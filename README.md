# comline_color_tools

---
## Tool Summary
Command line tools to (ANSI) colorize DNA sequences, columns, or numbers 
found within text files. Useful for bioinformatics or data analysis.

| Tool              | Version | Use
| ----------------- |:----- |:----
| **color_cols.pl** | V0.6 | Color specific columns within text
| **color_nums.pl** | V0.3 | Color numbers within text
| **color_seq.pl**  | V0.6 | Colors DNA sequence characters within text


---
## History
- 5/27/14 RTK
- 1/15/15 RTK (update; Renamed from comline color seq num)
- 3/31/15 RTK (update color cols.pl)
- 4/8/16 RTK; Update color_seq to support lowercase and not (inverse)
- 4/23/16 RTK; Update color_seq: Add -cran to restrict columns; Fix off-by-one bug with -bran
- 10/7/17 RTK; Update all three scripts and use doc too.
- 12/13/17 RTK; Update color_cols 0.54 to 0.55; add -ic
- 12/20/19 RTK; Update; Remove (local) includes; /usr/bin/env perl -w


---
## Background and overview
The color scripts are simple command line filters intended to colorize specific value-associated “words” contained within simple ASCII text. This is useful to highlight specific values for quick value identification and pattern visualization. The tools take text from a file or standard input then output this with ANSI escape sequences interjected to color specific characters in a terminal display. All tools also accept various command line options to allow user control over character or token selection and color choice.

**Use** is described in the document *comline_color_seq_num_use.pdf*. This also describes options and shows colored screenshots corresponding to example usage of all scripts.

Example test-case files include a fasta format sequence file ("examp.fas") and several number-containing files (*.mat)


---
## Dependencies

These perl modules are required:

| Module | Use
| ----------------- |:----
| Term::ANSIColor   | For color encoding
| Getopt::Long      | For command line processing
| Readonly          | For constants
| Carp              |

---

**To install** above modeules, try this:

`cpan install ANSIColor Getopt Readonly Carp`

Or you may need to use sudo:

`sudo cpan install ANSIColor Getopt Readonly Carp`


---
## Limitations / To do

**General**

Cook up some test case / example case scripts.

**color_seq.pl**

Lines are considered independently; Windows of base type cannot wrap for multi-line sequence formats like fasta.

**color_nums.pl**

Would be nice to have more than three colors (though given the ASNI pallete, what can one expect!)

