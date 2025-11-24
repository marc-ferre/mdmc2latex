#!/opt/homebrew/bin/perl
# Convert Markdown QCM to AMC-questionmult
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Pandoc qw(--wrap=none);    # check at first use
use Pandoc 1.12;               # check at compile time
Pandoc->require(1.12);         # check at run time

# Default strings (Markdown format)
my $prequestion_string   = '';
my $completemulti_string = 'Aucune des propositions ci-dessus n’est exacte.';
my $a_bullet             = '   A.  ';

my ( $q_first_id, $keep_md4docx, $help ) = ( '1', 0, 0 );
GetOptions(
    'fid=i' => \$q_first_id,      ### TO DO
    'keep'  => \$keep_md4docx,    ### TO DO
    'help'  => \$help
);

# Print help
if ( $help or not defined( $ARGV[0] ) ) {
    print "Usage: $0 <Markdown QCM file> --fid <First question number>\n";
    exit;
}

# Manage in and out files
my $md_path = $ARGV[0];
open IN, '<', $md_path or die $!;
my ( $md_base, $md_dir, $md_ext ) = fileparse( $md_path, ('.md') );
my $latex_path = $md_dir . $md_base . '.tex';
open OUT, '>', $latex_path or die $!;
my $date = localtime();
print OUT format_comment(
    "Converted from: $md_path on $date --- Marc FERRE. ALL RIGHTS RESERVED."),
  "\n\n";

my ( $q_into, $a_into ) = ( 0, 0 );
my ( $q_id, $a_id )     = ( 1, 0 );    ### TO DO
my $questions_string = '';
my @answers_string   = ();
my @answers_eval     = ();

# Parse in file
while ( my $line = <IN> ) {
    chomp $line;
    $line =~ s/^\s+|\s+$//g;           # Trim beginning and ending blanks

    # ID line
    if ( $line =~ m/^## \[(.+)\]/ ) {
        if ($a_into) {
            die
"QCM formatting issue at question $q_id: closed answers expected\n";
        }
        else {
            $q_into = 1;
            print OUT '\begin{questionmult}{' . $1 . '}', "\n";
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
            die
"QCM formatting issue at question $q_id: opened question expected\n";
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
            die
"QCM formatting issue at question $q_id: closed answers expected\n";
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
            if ( scalar(@answers_string) != 4 ) {
                die
"QCM formatting issue at question $q_id: 4 answers expected\n";
            }
            else {
                # Print questions lines
                print OUT convert($questions_string), "\n";
                $questions_string = '';

                # Print answers lines
                print OUT "\t" . '\begin{reponses}', "\n";
                for ( my $i = 0 ; $i < 4 ; $i++ ) {
                    print OUT "\t\t";
                    print OUT format_true( $answers_string[$i] )
                      if $answers_eval[$i] eq '+';
                    print OUT format_false( $answers_string[$i] )
                      if $answers_eval[$i] eq '-';
                    print OUT "\n";
                }
                print OUT "\t"
                  . '\end{reponses}' . "\n"
                  . '\end{questionmult}' . "\n\n";

                @answers_string = ();
                @answers_eval   = ();
            }
        }
    }

    # Heading line(s)
    elsif ( not $q_into and !$a_into ) {
        print OUT format_comment($line), "\n";
    }

    # Unexpected condition
    else {
        die "QCM formatting issue at question $q_id: unexpected condition\n";
    }
}
close IN;
close OUT;

# Convert with pandoc
pandoc or die "pandoc executable not found";             # Check executable
pandoc->version > 1.12 or die "pandoc >= 1.12 required"; # Check minimum version

print ">>> QCM file successfully converted to AMC-LaTeX file: $latex_path\n";

#################
### FUNCTIONS ###
#################

sub convert {
    my ($in) = @_;

    my $out = pandoc->convert( 'markdown' => 'latex', $in );
    chomp $out;
    $out =~ s/\\pandocbounded\{([^}]*)\}/$1/g;
    $out =~ s/\\def\\LTcaptype\{none\}/\\def\\LTcaptype\{0\}/g;
    $out =~ s/\x{2009}/ /g;
    return $out;
}

sub format_comment {
    my ($string) = @_;

    return "% $string";
}

sub format_true {
    my ($string) = @_;

    return '\bonne{', convert($string), '}';
}

sub format_false {
    my ($string) = @_;

    return '\mauvaise{', convert($string), '}';
}
