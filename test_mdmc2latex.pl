#!/usr/bin/env perl
# Tests for mdmc2latex.pl
use strict;
use warnings;
use Test::More;

my $none_of_the_above = q{Aucune de ces réponses n'est correcte.};

# Test basic functionality by running the script on a test file
sub test_script_execution {
    my $test_file = 'examples/sample_valid.mdmc';
    my $output_file = 'examples/sample_valid.tex';

    # Run the script
    system("perl mdmc2latex.pl $test_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Script executes without error on valid file");

    # Check if output file exists
    ok(-f $output_file, "Output file is created");

    # Open output file to check for problematic LaTeX constructs
    open my $fh, '<', $output_file or die "Can't open $output_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Ensure we didn't generate \def\LTcaptype{0}
        unlike($content, qr/\\def\\LTcaptype\{0\}/, "No \\\\def\\LTcaptype{0} present in output");
        unlike($content, qr/\\def\\LTcaptype\{none\}/, "No \\\\def\\LTcaptype{none} present in output");

    # Check that question IDs are Q-prefixed: \begin{questionmult}{Q<digits>}
    my @bad_ids = ($content =~ /\\begin\{questionmult\}\{([^}]+)\}/g);
    foreach my $id (@bad_ids) {
        like($id, qr/^Q\d+$/, "Question ID '$id' is Q-prefixed numeric");
        # If an LTcaptype is present, ensure it is 'table' and not numeric/none
        my @ltcaps = ($content =~ /\\def\\LTcaptype\{([^}]+)\}/g);
        foreach my $lt (@ltcaps) {
            like($lt, qr/^relax$/, "LTcaptype is 'relax' (not '0' nor 'none')");
        }
    }

    # Clean up output file
    unlink $output_file if -f $output_file;
}

# Test error handling
sub test_error_handling {
    my $invalid_file = 'examples/sample_invalid.mdmc';

    # Run the script on invalid file
    system("perl mdmc2latex.pl $invalid_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;

    isnt($exit_code, 0, "Script fails on invalid file with fewer than 4 answers");
}

sub test_ltcaptype_option {
    my $test_file = 'examples/sample_withltcaptype.mdmc';
    my $output_file = 'examples/sample_withltcaptype.tex';

    # Default behavior should replace 'none' with 'table'
    system("perl mdmc2latex.pl $test_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;
    is($exit_code, 0, "Script executes without error on ltcaptype sample");
    ok(-f $output_file, "Output file is created for ltcaptype sample");
    open my $fh, '<', $output_file or die "Can't open $output_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    like($content, qr/\\def\\LTcaptype\{table\}/, "Default replacement uses 'table'");
    unlink $output_file if -f $output_file;

    # With --ltcaptype=relax we should see \relax used
    system("perl mdmc2latex.pl --ltcaptype=relax $test_file > /dev/null 2>&1");
    $exit_code = $? >> 8;
    is($exit_code, 0, "Script executes with --ltcaptype=relax");
    ok(-f $output_file, "Output file is created for ltcaptype sample with relax");
    open $fh, '<', $output_file or die "Can't open $output_file: $!";
    $content = do { local $/; <$fh> };
    close $fh;
    like($content, qr/\\def\\LTcaptype\{\\relax\}/, "ltcaptype=relax results in \\relax");
    unlink $output_file if -f $output_file;

    # Invalid option should exit with non-zero
    system("perl mdmc2latex.pl --ltcaptype=invalid $test_file > /dev/null 2>&1");
    $exit_code = $? >> 8;
    isnt($exit_code, 0, "Invalid ltcaptype value should cause error exit");
}

sub test_four_and_five_answer_rules {
    my $four_input = 'tests/corpus/four_answers_all_false.mdmc';
    my $four_output = 'tests/corpus/four_answers_all_false.tex';

    system("perl mdmc2latex.pl $four_input > /dev/null 2>&1");
    my $exit_code = $? >> 8;
    is($exit_code, 0, "4-answer corpus converts successfully");
    ok(-f $four_output, "4-answer corpus output file exists");

    open my $fh, '<', $four_output or die "Can't open $four_output: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    like($content, qr/\\bonne\{[^}]*Aucune de ces réponses n'est correcte\./, "4 answers all false => 'Aucune...' becomes correct");
    unlink $four_output if -f $four_output;

    my $five_input = 'tests/corpus/five_answers_no_extra.mdmc';
    my $five_output = 'tests/corpus/five_answers_no_extra.tex';

    system("perl mdmc2latex.pl $five_input > /dev/null 2>&1");
    $exit_code = $? >> 8;
    is($exit_code, 0, "5-answer corpus converts successfully");
    ok(-f $five_output, "5-answer corpus output file exists");

    open $fh, '<', $five_output or die "Can't open $five_output: $!";
    $content = do { local $/; <$fh> };
    close $fh;

    unlike($content, qr/Aucune de ces réponses n'est correcte\./, "5 answers => no extra 'Aucune...' answer added");
    unlink $five_output if -f $five_output;
}

sub test_sanitize_flag {
    my $test_file = 'examples/sample_withltcaptype.mdmc';
    my $output_file = 'examples/sample_withltcaptype.tex';

    # Run mdmc2latex with --sanitize and default ltcaptype
    system("perl mdmc2latex.pl --sanitize --ltcaptype=table $test_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;
    is($exit_code, 0, "Script executes successfully with --sanitize");
    ok(-f $output_file, "Output file created by --sanitize");
    ok(-f "$output_file.bak", "Backup file created by sanitizer (\*.tex.bak)");
    open my $fh, '<', $output_file or die "Can't open $output_file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    like($content, qr/\\def\\LTcaptype\{table\}/, "Sanitizer kept/normalized LTcaptype to 'table'");
    unlink $output_file if -f $output_file;
    unlink "$output_file.bak" if -f "$output_file.bak";
}

sub test_sanitize_dry_run_flag {
    my $test_file = 'examples/sample_withltcaptype.mdmc';
    my $output_file = 'examples/sample_withltcaptype.tex';

    # Create base file using mdmc2latex
    system("perl mdmc2latex.pl --ltcaptype=table $test_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;
    is($exit_code, 0, "Base conversion OK for dry-run test");
    ok(-f $output_file, "Output file exists before dry-run");

    # Run with --sanitize and --sanitize-dry-run
    system("perl mdmc2latex.pl --sanitize --sanitize-dry-run --ltcaptype=table $test_file > /dev/null 2>&1");
    $exit_code = $? >> 8;
    is($exit_code, 0, "Script executes successfully with --sanitize --sanitize-dry-run");
    ok(-f $output_file, "Output file still exists after dry-run");
    ok(!-f "$output_file.bak", "No backup file created since sanitizer ran in dry-run");

    # Clean up
    unlink $output_file if -f $output_file;
}

# Run tests
test_script_execution();
test_error_handling();
test_ltcaptype_option();
test_four_and_five_answer_rules();
test_sanitize_flag();
test_sanitize_dry_run_flag();

done_testing();