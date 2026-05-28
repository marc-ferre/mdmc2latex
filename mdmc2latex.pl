#!/opt/homebrew/bin/perl
# Convert Markdown QCM to AMC-questionmult
BEGIN {
    binmode(STDOUT, ':encoding(UTF-8)');
    binmode(STDERR, ':encoding(UTF-8)');
}
use strict;
use warnings;
use utf8;
use Encode qw(decode FB_CROAK);
use open qw(:std :encoding(UTF-8));
use Getopt::Long qw(GetOptions);
use File::Basename;
use IPC::Open3 qw(open3);
use Symbol qw(gensym);
use Term::ANSIColor qw(:constants);

# Default strings (Markdown format)
my $prequestion_string   = '';
my $completemulti_string = q{Aucune de ces réponses n'est correcte.};
my $a_bullet             = '   A.  ';

my ( $q_first_id, $keep_md4docx, $help, $ltcaptype, $sanitize, $sanitize_dryrun, $normalize_spaces ) = ( '1', 0, 0, 'table', 0, 0, 1 );
GetOptions(
    'fid=i' => \$q_first_id,      # First question ID (not implemented yet)
    'keep'  => \$keep_md4docx,    # Keep intermediate MD file (not implemented yet)
    'help'  => \$help
    , 'ltcaptype=s' => \$ltcaptype
    , 'sanitize' => \$sanitize
    , 'sanitize-dry-run' => \$sanitize_dryrun
    , 'normalize-spaces!' => \$normalize_spaces
);

# Print help
if ( $help or not defined( $ARGV[0] ) ) {
    print_usage();
    exit;
}

# Validate input file
my $md_path = $ARGV[0];
if (defined $md_path && !utf8::is_utf8($md_path)) {
    eval { $md_path = decode('UTF-8', $md_path, FB_CROAK); 1 }
      or error_exit("Input path is not valid UTF-8: $ARGV[0]");
}
unless ( -f $md_path && -r $md_path ) {
    error_exit("Input file '$md_path' does not exist or is not readable.");
}

# Manage in and out files
my ( $md_base, $md_dir, $md_ext ) = fileparse( $md_path, ('.mdmc', '.md') );
my $latex_path = $md_dir . $md_base . '.tex';

# Normalize ltcaptype option
$ltcaptype = lc($ltcaptype // 'table');
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

# Run sanitation if requested
if ($sanitize) {
    my $sanitizer = 'tools/sanitize_tex.pl';
    if (-f $sanitizer) {
        my $cmd = "perl $sanitizer --ltcaptype=$ltcaptype";
        if ($sanitize_dryrun) { $cmd .= ' --dry-run'; }
        $cmd .= ' ' . $latex_path;
        print "Running sanitizer: $cmd\n";
        my $rc = system($cmd);
        if ($rc != 0) {
            warn sprintf("Sanitizer returned non-zero exit code: %d\n", $rc >> 8);
        }
    }
    else {
        warn "Sanitizer script not found (tools/sanitize_tex.pl). Skipping sanitize.\n";
    }
}

#################
### FUNCTIONS ###
#################

# Print usage information
sub print_usage {
    print "Usage: $0 <Markdown QCM file> [--fid <First question number>]\n";
    print "Options:\n";
    print "  --fid=i    First question number (default: 1, not implemented)\n";
    print "  --keep     Keep intermediate Markdown file (not implemented)\n";
    print "  --ltcaptype=<table|figure|relax|none>  LTcaptype to use in generated LaTeX (default: table). 'none' is equivalent to 'relax' and avoids incrementing a counter.\n";
    print "  --sanitize  Run tools/sanitize_tex.pl on the generated .tex file (in-place).\n";
    print "  --sanitize-dry-run  Run sanitizer in dry-run (preview) mode; no files are modified but sanitizer is executed.\n";
    print "  --normalize-spaces / --no-normalize-spaces  Normalize Unicode spaces (U+2009/U+202F/U+00A0) in generated LaTeX (default: enabled).\n";
    print "  --help     Show this help message\n";
}

# Safe file opening
sub open_file {
    my ($mode, $path, $error_msg) = @_;
    my $open_mode = $mode;
    if ($mode eq '<' || $mode eq '>') {
        $open_mode .= ':encoding(UTF-8)';
    }
    open my $fh, $open_mode, $path or error_exit("$error_msg: $!");
    return $fh;
}

# Error handling with clean exit
sub error_exit {
    my ($msg) = @_;
    warn "Error: $msg\n";
    exit 1;
}

sub flush_question {
    my ($out_fh, $questions_string_ref, $answers_string_ref, $answers_eval_ref, $stats, $q_id) = @_;

    my $num_answers = scalar(@{$answers_string_ref});
    if ( $num_answers < 4 || $num_answers > 5 ) {
        error_exit("QCM formatting issue at question $q_id: 4 or 5 answers expected, got $num_answers");
    }

    print $out_fh convert(${$questions_string_ref}), "\n";
    ${$questions_string_ref} = '';

    print $out_fh "\t" . '\begin{reponses}', "\n";

    my $true_count = 0;
    my $false_count = 0;
    for ( my $i = 0 ; $i < $num_answers ; $i++ ) {
        print $out_fh "\t\t";
        if ( $answers_eval_ref->[$i] eq '+' ) {
            print $out_fh format_true( $answers_string_ref->[$i] );
            $true_count++;
        }
        else {
            print $out_fh format_false( $answers_string_ref->[$i] );
            $false_count++;
        }
        print $out_fh "\n";
    }

    if ( $num_answers == 4 ) {
        print $out_fh "\t\t";
        if ( $true_count == 0 ) {
            print $out_fh format_true($completemulti_string);
            $true_count++;
        }
        else {
            print $out_fh format_false($completemulti_string);
            $false_count++;
        }
        print $out_fh "\n";
    }

    print $out_fh "\t"
      . '\end{reponses}' . "\n"
      . '\end{questionmult}' . "\n\n";

    $stats->{questions}++;
    $stats->{answers} += $num_answers + ($num_answers == 4 ? 1 : 0);
    $stats->{correct} += $true_count;
    $stats->{incorrect} += $false_count;

    @{$answers_string_ref} = ();
    @{$answers_eval_ref}   = ();
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
                flush_question($out_fh, \$questions_string, \@answers_string, \@answers_eval, $stats, $q_id);
                $q_id++;  # Increment question counter for error messages
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
        flush_question($out_fh, \$questions_string, \@answers_string, \@answers_eval, $stats, $q_id);
        $q_id++;  # Increment question counter for error messages
    }

    return $stats;
}

# Check Pandoc availability and version
sub check_pandoc {
    my $version_output = `pandoc --version 2>&1`;
    my $exit_code = $? >> 8;
    if ($exit_code != 0) {
        error_exit("pandoc executable not found");
    }

    my ($version) = $version_output =~ /pandoc\s+(\d+(?:\.\d+)+)/;
    unless ($version && $version ge '1.12') {
        error_exit("pandoc >= 1.12 required, found " . ($version // 'unknown'));
    }
}

# Convert Markdown to LaTeX using Pandoc
sub convert {
    my ($in) = @_;

    my $out = run_pandoc_convert($in);
    chomp $out;
    $out =~ s/\\pandocbounded\{([^}]*)\}/$1/g;
    # Normalize any LTcaptype value that could have been produced by pandoc
    # Replace occurrences of 'none' or '0' by the user-specified $ltcaptype
    my $lt_value_raw = $ltcaptype eq 'relax' ? '\\relax' : $ltcaptype;
    my $lt_replacement = '\\def\\LTcaptype{' . $lt_value_raw . '}';
    # Replace any current definition of LTcaptype (none|0|table|figure|...) by the selected value
    $out =~ s/\\def\\LTcaptype\{[^}]*\}/$lt_replacement/g;
    $out = normalize_includegraphics($out);
    if ($normalize_spaces) {
        $out = normalize_unicode_spaces($out);
    }
    return $out;
}

sub run_pandoc_convert {
    my ($input) = @_;

    my $stderr = gensym;
    my $pid = open3(my $child_in, my $child_out, $stderr,
        'pandoc', '-f', 'markdown', '-t', 'latex', '--wrap=none');

    binmode($child_in, ':encoding(UTF-8)');
    binmode($child_out, ':encoding(UTF-8)');
    binmode($stderr, ':encoding(UTF-8)');

    print {$child_in} $input;
    close $child_in;

    local $/;
    my $stdout = <$child_out> // '';
    my $stderr_text = <$stderr> // '';

    waitpid($pid, 0);
    my $exit_code = $? >> 8;
    if ($exit_code != 0) {
        error_exit("pandoc conversion failed: $stderr_text");
    }

    return $stdout;
}

# Ensure images fit within text width unless explicit sizing already exists.
sub normalize_includegraphics {
    my ($text) = @_;
    return '' unless defined $text;

    $text =~ s/\\includegraphics(?:\[([^\]]*)\])?\{([^}]*)\}/fit_includegraphics($1, $2)/eg;

    return $text;
}

sub fit_includegraphics {
    my ($opts, $path) = @_;
    $opts = '' unless defined $opts;
    $path = '' unless defined $path;

    if ($opts =~ /(?:^|,)\s*(?:width|height|scale)\s*=/) {
        return $opts ne ''
          ? "\\includegraphics[$opts]{$path}"
          : "\\includegraphics{$path}";
    }

    return $opts ne ''
      ? "\\includegraphics[$opts,width=\\linewidth]{$path}"
      : "\\includegraphics[width=\\linewidth]{$path}";
}

# Normalize Unicode spacing chars that break pdfLaTeX in AMC workflows.
sub normalize_unicode_spaces {
    my ($text) = @_;
    return '' unless defined $text;

    if (utf8::is_utf8($text)) {
        # Character-oriented strings.
        $text =~ s/[\x{2009}\x{202F}\x{00A0}\x{FFFD}]/ /g;
    }
    else {
        # Byte-oriented UTF-8 strings (no internal Unicode flag).
        # Replace UTF-8 byte sequences for U+2009, U+202F and U+00A0.
        # Important: do not replace a raw 0xA0 byte, which would corrupt UTF-8
        # letters such as "à" (C3 A0).
        $text =~ s/\xE2\x80[\x89\xAF]/ /g;    # U+2009, U+202F
        $text =~ s/\xC2\xA0/ /g;               # U+00A0
        $text =~ s/\xEF\xBF\xBD/ /g;          # U+FFFD (replacement char)
    }

    return $text;
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

    # Re-assert UTF-8 output in case a loaded module changed stream layers.
    binmode(STDOUT, ':encoding(UTF-8)');

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