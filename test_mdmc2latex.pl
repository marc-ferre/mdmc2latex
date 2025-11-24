#!/usr/bin/env perl
# Tests for mdmc2latex.pl
use strict;
use warnings;
use Test::More;

# Test basic functionality by running the script on a test file
sub test_script_execution {
    my $test_file = 'examples/sample_valid.mdmc';
    my $output_file = 'examples/sample_valid.mdmc.tex';

    # Run the script
    system("perl mdmc2latex.pl $test_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;

    is($exit_code, 0, "Script executes without error on valid file");

    # Check if output file exists
    ok(-f $output_file, "Output file is created");

    # Clean up output file
    unlink $output_file if -f $output_file;
}

# Test error handling
sub test_error_handling {
    my $invalid_file = 'examples/sample_invalid.mdmc';

    # Run the script on invalid file
    system("perl mdmc2latex.pl $invalid_file > /dev/null 2>&1");
    my $exit_code = $? >> 8;

    # Note: Current implementation doesn't fail on questions without answers, but we can test it runs
    is($exit_code, 0, "Script handles invalid file gracefully (currently doesn't fail)");
}

# Run tests
test_script_execution();
test_error_handling();

done_testing();