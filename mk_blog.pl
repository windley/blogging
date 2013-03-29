#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use Data::Dumper;

use Blog qw/ :all /;

# global options
use vars qw/ %opt /;
my $opt_string = 'pf:c:';
getopts( "$opt_string", \%opt ) or usage();

my $config = read_config($opt{'c'});

my $entry_file = "";
if ($opt{'f'} ) {
    $entry_file = $opt{'f'} ;
#    print "$entry_dir$entry_file\n"; 
} else {
    die "You must specify an entry_file\n";
}

my $complete_filename = $config->{'entry_dir'}.$entry_file;
my ($result, $meta) = make_blog_entry($complete_filename, $config);

if ($opt{p}) { 
  print $result 
} else {

  output_blog_file($result, $config, $meta);

}

1;



#
# Message about this program and how to use it
#
sub usage {
    print STDERR << "EOF";

Formats blog enties.

usage: $0 [-h?c] -f individual_entry

 -h|?       : this (help) message
 -f file    : input file
 -c config  : configuration file
 -p         : print result instead of saving

example: $0 -f "2013/02/23/131456.html"

EOF
    exit;
}
