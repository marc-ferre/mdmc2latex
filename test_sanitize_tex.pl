#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Copy;

my $tmp = tempdir(CLEANUP => 1);
my $sample = 'examples/sample_withltcaptype.mdmc';
# Use the generated sample as baseline
my $sample_tex = 'examples/sample_withltcaptype.mdmc.tex';

# generate a simple .tex sample: reuse the existing mdmc2latex output as baseline
system("perl mdmc2latex.pl $sample > /dev/null 2>&1");
ok(-f $sample_tex, 'Generated sample .tex present');

# Copy sample for test
my $copy = "$tmp/sample.tex";
copy($sample_tex, $copy) or die "Copy failed: $!";

# Run sanitizer on small copy
system("perl tools/sanitize_tex.pl --ltcaptype=relax $copy > /dev/null 2>&1");
my $exit = $? >> 8;
is($exit, 0, 'Sanitizer exited 0');

open my $fh, '<', $copy or die "Can't open $copy: $!";
my $content = do { local $/; <$fh> };
close $fh;

like($content, qr/\\def\\LTcaptype\{\\relax\}/, 'LTcaptype replaced with \\relax');
like($content, qr/\\resizebox\{\\linewidth\}\{!\}\{\\begin\{minipage\}\{\\linewidth\}/, 'Longtable wrapped with resizebox + minipage');

# Test includegraphics handling
my $img_sample = "$tmp/sample_img.tex";
open my $imgfh, '>', $img_sample or die "Can't write $img_sample: $!";
print $imgfh "\\includegraphics[keepaspectratio]{images/pic.png}\\n";
close $imgfh;
system("perl tools/sanitize_tex.pl --ltcaptype=relax $img_sample > /dev/null 2>&1");
is(($? >> 8), 0, 'Sanitizer executed on sample image file');
open $imgfh, '<', $img_sample or die "Can't open $img_sample: $!";
my $img_content = do { local $/; <$imgfh> };
close $imgfh;
like($img_content, qr/\\adjustbox\{max width=\\linewidth\}\{\\includegraphics(\[[^\]]*\])?\{images\/pic.png\}\}/, 'Includegraphics wrapped with adjustbox max width (no enlargement)');

done_testing();
