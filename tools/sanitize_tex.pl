#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Find;
use File::Copy;

my $ltcaptype = 'relax';
my $dry_run    = 0;
my $help       = 0;
my $recursive  = 1;

GetOptions(
    'ltcaptype=s' => \$ltcaptype,
    'dry-run'     => \$dry_run,
    'recursive!'  => \$recursive,
    'help'        => \$help,
    'verbose'     => \my $verbose
);

if ($help) {
    print "Usage: $0 [--ltcaptype=table|figure|relax|none] [--dry-run] <path>...\n";
    exit 0;
}

$ltcaptype = lc($ltcaptype // 'relax');
if ($ltcaptype eq 'none') { $ltcaptype = 'relax'; }
unless ($ltcaptype =~ /^(?:table|figure|relax)$/) {
    die "Invalid ltcaptype value: $ltcaptype\n";
}

my @targets = @ARGV ? @ARGV : ('.');

my @files;
print "Targets: @targets\n" if $verbose;
foreach my $t (@targets) {
    if ( -d $t ) {
        # Use external find for robustness across absolute paths
        my @found = `find "$t" -type f -name \"*.tex\"`;
        chomp @found;
        push @files, @found;
    }
    elsif ( -f $t ) {
        # accept files that include .tex anywhere in name (e.g. .mdmc.tex)
        print "check file: $t -> -f? ", (-f $t ? 'yes' : 'no'), "\n" if $verbose;
        my $name_ok = ($t =~ /\.tex\z/i);
        print "name match? ", ($name_ok ? 'yes' : 'no'), "\n" if $verbose;
        if ($name_ok) {
            push @files, $t;
            print "Pushed $t\n" if $verbose;
        }
    }
}
print "Found files: @files\n" if $verbose;

if (!@files) { print "No .tex files found to sanitize\n"; exit 0; }

foreach my $file (@files) {
    print "Processing: $file\n";
    open my $fh, '<', $file or do { warn "Cannot open $file: $!\n"; next; };
    my $content = do { local $/; <$fh> };
    close $fh;

    my $value = ($ltcaptype eq 'relax') ? '\\relax' : $ltcaptype;
    # Replace any existing defLTcaptype with desired value
    $content =~ s/\\def\\LTcaptype\{[^}]*\}/\\def\\LTcaptype\{$value\}/g;

    # Determine whether adjustbox is available or should be injected
    my $has_adjustbox = ($content =~ /\\usepackage\{adjustbox\}/);
    my $has_preamble = ($content =~ /\\documentclass[^\n]*\n/) || ($content =~ /\\begin\{document\}/);

    # If adjustbox is not present but we have a preamble, inject it safely
    if (!$has_adjustbox && $has_preamble) {
        if ($content =~ s/(\\documentclass[^\n]*\n)/$1 . "\\usepackage{adjustbox}\\n"/e) {
            print "Inserted \\usepackage{adjustbox} into preamble\n" if $verbose;
            $has_adjustbox = 1;
        }
        elsif ($content =~ s/(\\begin\{document\})/"\\usepackage{adjustbox}\\n$1"/e) {
            print "Inserted \\usepackage{adjustbox} before \\begin{document}\n" if $verbose;
            $has_adjustbox = 1;
        }
    }

    # Only wrap includegraphics if adjustbox will be available
    if ($has_adjustbox) {
        # Replace includegraphics[opts]{file} (no width present) -> \adjustbox{max width=\linewidth}{\includegraphics[opts]{file}}
        $content =~ s{\\includegraphics(\[([^\]]*)\])?\{([^\}]+)\}}{
            my ($opts, $optstr, $file) = ($1, $2, $3);
            if (defined $optstr && $optstr =~ /(^|,)\s*width\s*=/) {
                # width explicitly set: do not change
                "\\includegraphics" . ($opts // "") . "{" . $file . "}";
            } else {
                "\\adjustbox{max width=\\linewidth}{\\includegraphics" . ($opts // "") . "{" . $file . "}}";
            }
        }egx;
    }

    # Wrap longtable inside resizebox+minipage to avoid overflow
    # We insert a wrapper before \begin{longtable} and after \end{longtable}
    $content =~ s/\\begin\{longtable\}/\\resizebox{\\linewidth}{!}{\\begin{minipage}{\\linewidth}\\begin{longtable}/g;
    $content =~ s/\\end\{longtable\}/\\end{longtable}\\end{minipage}}/g;

    # We already inject adjustbox only when it is safe (documentclass or begin{document}).
    # No fallback injection is performed for snippets to avoid \usepackage before \documentclass issues.

    if ($dry_run) {
        print "--- Dry-run: not writing changes for $file\n";
    }
    else {
        # create backup
        my $bak = "$file.bak";
        File::Copy::copy($file, $bak) or warn "Cannot backup $file -> $bak: $!\n";
        open my $out, '>', $file or do { warn "Cannot open $file for write: $!\n"; next; };
        print $out $content;
        close $out;
        print "Sanitized: $file (backup -> $bak)\n";
    }
}

print "Done.\n";

__END__
