#!/usr/bin/perl -w
use strict;

# This is a convinience file that runs the blogging commands for me. 

use Getopt::Std;

use Blog qw/ :all /;


# global options
use vars qw/ %opt /;
my $opt_string = 'ab:v';
getopts( "$opt_string", \%opt ) or usage();

my $blog_id = $opt{'b'} || 'tm';
my $scope = $opt{'a'};

my $home_dir = "/Users/pjw";
my $blogging_dir = "$home_dir/Dropbox/Documents/blogging";
my $config_file = "$blogging_dir/$blog_id/config.yml";
my $blog_dir_name = $blog_id."_blog";
my $fold_dir = "$home_dir/prog/perl/blog";

my $config = read_config($config_file);


my $dest = $config->{'blog_destination'};


my @fold_cmd = ("$fold_dir/fold_blog.pl");
push @fold_cmd, "-a" if defined $scope;
push @fold_cmd, "-c";
push @fold_cmd, $config_file;
push @fold_cmd, "-v" if defined $opt{'v'};

my $cmd = join(" ", @fold_cmd);

system($cmd) == 0 || die "Could not execute fold_blog.pl, $?";

my @rsync_cmd = ("rsync", "-arv", "--delete", "$blogging_dir/$blog_dir_name/*", $dest);

$cmd = join(" ", @rsync_cmd);

system($cmd) == 0 || die "Could not execute rsync, $?";
 

1;



#
# Message about this program and how to use it
#
sub usage {
    print STDERR << "EOF";

Formats blog enties.

usage: $0 [-h?] -b blog_id

 -h|?       : this (help) message
 -f file    : input file
 -c config  : configuration file
 -p         : print result instead of saving

example: $0 -b tm

EOF
    exit;
}
