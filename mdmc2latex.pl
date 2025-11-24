#!/opt/homebrew/bin/perl
# Convert Markdown QCM to AMC-questionmult
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Pandoc qw(--wrap=none);    # check at first use
use Pandoc 1.12;               # check at compile time
Pandoc->require(1.12);         # check at run time
use Term::ANSIColor qw(:constants);

# Default strings (Markdown format)
my $prequestion_string   = '';
my $completemulti_string = 'Aucune des propositions ci-dessus n’est exacte.';
my $a_bullet             = '   A.  ';

my ( $q_first_id, $keep_md4docx, $help, $ltcaptype ) = ( '1', 0, 0, 'relax' );
GetOptions(
    'fid=i' => \$q_first_id,      # First question ID (not implemented yet)
    'keep'  => \$keep_md4docx,    # Keep intermediate MD file (not implemented yet)
    'help'  => \$help
    , 'ltcaptype=s' => \$ltcaptype
);

# Print help
if ( $help or not defined( $ARGV[0] ) ) {
    print_usage();
    exit;
}

# Validate input file
my $md_path = $ARGV[0];
unless ( -f $md_path && -r $md_path ) {
    error_exit("Input file '$md_path' does not exist or is not readable.");
}

# Manage in and out files
my ( $md_base, $md_dir, $md_ext ) = fileparse( $md_path, ('.md') );
my $latex_path = $md_dir . $md_base . '.tex';

# Normalize ltcaptype option
$ltcaptype = lc($ltcaptype // 'relax');
if ($ltcaptype eq 'none') { $ltcaptype = 'relax'; }
unless ($ltcaptype =~ /^(?:table|figure|relax)$/) {
    error_exit("Invalid --ltcaptype value '$ltcaptype'. Allowed: table|figure|relax|none");
}

# Open files safely
my $in_fh = open_file('<', $md_path, "Cannot open input file '$md_path'");
my $out_fh = open_file('>', $latex_path, "Cannot open output file '$latex_path'");

my $date = localtime();
print $out_fh format_comment(
    "Converted from: $md_path on $date --- Marc FERRE. ALL RIGHTS RESERVED."),
  "\n\n";

# Parse and process the file
my $stats = process_file($in_fh, $out_fh);

close $in_fh;
close $out_fh;

# Convert with pandoc
check_pandoc();

# Display success message with statistics
print_success($latex_path, $stats);

#################
### FUNCTIONS ###
#################

# Print usage information
sub print_usage {
    print "Usage: $0 <Markdown QCM file> [--fid <First question number>]\n";
    print "Options:\n";
    print "  --fid=i    First question number (default: 1, not implemented)\n";
    print "  --keep     Keep intermediate Markdown file (not implemented)\n";
    print "  --ltcaptype=<table|figure|relax|none>  LTcaptype to use in generated LaTeX (default: relax). 'none' is equivalent to 'relax' and avoids incrementing a counter.\n";
    print "  --help     Show this help message\n";
}

# Safe file opening
sub open_file {
    my ($mode, $path, $error_msg) = @_;
    open my $fh, $mode, $path or error_exit("$error_msg: $!");
    return $fh;
}

# Error handling with clean exit
sub error_exit {
    my ($msg) = @_;
    warn "Error: $msg\n";
    exit 1;
}

# Process the input file
sub process_file {
    my ($in_fh, $out_fh) = @_;

    my ( $q_into, $a_into ) = ( 0, 0 );
    my ( $q_id, $a_id )     = ( 1, 0 );
    my $questions_string = '';
    my @answers_string   = ();
    my @answers_eval     = ();
    my $stats = { questions => 0, answers => 0, correct => 0, incorrect => 0 };

    while ( my $line = <$in_fh> ) {
        chomp $line;
        $line =~ s/^\s+|\s+$//g;    # Trim beginning and ending blanks

        # ID line
        if ( $line =~ m/^## \[(.+)\]/ ) {
            if ($a_into) {
                error_exit("QCM formatting issue at question $q_id: closed answers expected");
            }
            else {
                $q_into = 1;
                my $question_id = 'Q' . $q_id; # Prefix with letter to ensure LaTeX counter names are letters first
                print $out_fh '\begin{questionmult}{' . $question_id . '}', "\n";
                $questions_string .= $prequestion_string . "\n"
                  unless $prequestion_string eq '';
            }
        }

        # Question line
        elsif ( $line =~ m/^### (.+)$/ ) {
            if ($q_into) {
                $questions_string .= $1 . "\n";
            }
            else {
                error_exit("QCM formatting issue at question $q_id: opened question expected");
            }
        }

        # Answers
        elsif ( $line =~ m/^([\+-]) (.+)$/ ) {
            $q_into                = 0;
            $a_into                = 1;
            $answers_eval[$a_id]   = $1;
            $answers_string[$a_id] = $2;
            $a_id++;
        }

        # Line(s) between ID and question
        elsif ($q_into) {
            if ($a_into) {
                error_exit("QCM formatting issue at question $q_id: closed answers expected");
            }
            else {
                $questions_string .= $line . "\n";
            }
        }

        # End of answers: print answers
        elsif ( $line =~ m/^[_\s]*$/ ) {
            if ($a_into) {
                $a_into = 0;
                $a_id   = 0;
                my $num_answers = scalar(@answers_string);
                if ( $num_answers < 2 || $num_answers > 4 ) {
                    error_exit("QCM formatting issue at question $q_id: between 2 and 4 answers expected, got $num_answers");
                }
                else {
                    # Print questions lines
                    print $out_fh convert($questions_string), "\n";
                    $questions_string = '';

                    # Print answers lines
                    print $out_fh "\t" . '\begin{reponses}', "\n";
                    for ( my $i = 0 ; $i < $num_answers ; $i++ ) {
                        print $out_fh "\t\t";
                        print $out_fh format_true( $answers_string[$i] )
                          if $answers_eval[$i] eq '+';
                        print $out_fh format_false( $answers_string[$i] )
                          if $answers_eval[$i] eq '-';
                        print $out_fh "\n";
                    }
                    print $out_fh "\t"
                      . '\end{reponses}' . "\n"
                      . '\end{questionmult}' . "\n\n";

                    # Update statistics
                    $stats->{questions}++;
                    $stats->{answers} += $num_answers;
                    foreach my $eval (@answers_eval) {
                        if ($eval eq '+') {
                            $stats->{correct}++;
                        } else {
                            $stats->{incorrect}++;
                        }
                    }

                    @answers_string = ();
                    @answers_eval   = ();
                    $q_id++;  # Increment question counter for error messages
                }
            }
        }

        # Heading line(s)
        elsif ( not $q_into and !$a_into ) {
            print $out_fh format_comment($line), "\n";
        }

        # Unexpected condition
        else {
            error_exit("QCM formatting issue at question $q_id: unexpected condition");
        }
    }

    # Process remaining question if any at end of file
    if ($a_into) {
        $a_into = 0;
        $a_id   = 0;
        my $num_answers = scalar(@answers_string);
        if ( $num_answers < 2 || $num_answers > 4 ) {
            error_exit("QCM formatting issue at question $q_id: between 2 and 4 answers expected, got $num_answers");
        }
        else {
            # Print questions lines
            print $out_fh convert($questions_string), "\n";
            $questions_string = '';

            # Print answers lines
            print $out_fh "\t" . '\begin{reponses}', "\n";
            for ( my $i = 0 ; $i < $num_answers ; $i++ ) {
                print $out_fh "\t\t";
                print $out_fh format_true( $answers_string[$i] )
                  if $answers_eval[$i] eq '+';
                print $out_fh format_false( $answers_string[$i] )
                  if $answers_eval[$i] eq '-';
                print $out_fh "\n";
            }
            print $out_fh "\t"
              . '\end{reponses}' . "\n"
              . '\end{questionmult}' . "\n\n";

            # Update statistics
            $stats->{questions}++;
            $stats->{answers} += $num_answers;
            foreach my $eval (@answers_eval) {
                if ($eval eq '+') {
                    $stats->{correct}++;
                } else {
                    $stats->{incorrect}++;
                }
            }

            @answers_string = ();
            @answers_eval   = ();
            $q_id++;  # Increment question counter for error messages
        }
    }

    return $stats;
}

# Check Pandoc availability and version
sub check_pandoc {
    unless (pandoc) {
        error_exit("pandoc executable not found");
    }
    unless (pandoc->version >= 1.12) {
        error_exit("pandoc >= 1.12 required, found " . pandoc->version);
    }
}

# Convert Markdown to LaTeX using Pandoc
sub convert {
    my ($in) = @_;

    my $out = pandoc->convert( 'markdown' => 'latex', $in );
    chomp $out;
    $out =~ s/\\pandocbounded\{([^}]*)\}/$1/g;
    # Normalize any LTcaptype value that could have been produced by pandoc
    # Replace occurrences of 'none' or '0' by the user-specified $ltcaptype
    my $lt_value_raw = $ltcaptype eq 'relax' ? '\\relax' : $ltcaptype;
    my $lt_replacement = '\\def\\LTcaptype{' . $lt_value_raw . '}';
    # Replace any current definition of LTcaptype (none|0|table|figure|...) by the selected value
    $out =~ s/\\def\\LTcaptype\{[^}]*\}/$lt_replacement/g;
    $out =~ s/\x{2009}/ /g;
    return $out;
}

# Format as comment
sub format_comment {
    my ($string) = @_;
    return "% $string";
}

# Format correct answer
sub format_true {
    my ($string) = @_;
    return '\bonne{', convert($string), '}';
}

# Format incorrect answer
sub format_false {
    my ($string) = @_;
    return '\mauvaise{', convert($string), '}';
}

# Display success message with statistics
sub print_success {
    my ($latex_path, $stats) = @_;

    print GREEN, ">>> Conversion réussie !\n", RESET;
    print "Fichier AMC-LaTeX généré : ", CYAN, $latex_path, RESET, "\n\n";

    print BOLD, "Statistiques :\n", RESET;
    print "  Questions traitées : ", YELLOW, $stats->{questions}, RESET, "\n";
    print "  Réponses totales    : ", YELLOW, $stats->{answers}, RESET, "\n";
    print "  Réponses correctes  : ", GREEN, $stats->{correct}, RESET, "\n";
    print "  Réponses incorrectes: ", RED, $stats->{incorrect}, RESET, "\n";

    my $avg_answers = $stats->{questions} > 0 ? sprintf("%.1f", $stats->{answers} / $stats->{questions}) : 0;
    print "  Moyenne par question: ", BLUE, $avg_answers, RESET, " réponses\n";
}