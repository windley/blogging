#!/usr/bin/perl -w
use strict;

# This is a convinience file that runs the blogging commands for me. 

use Getopt::Std;

use lib '/Users/pjw/prog/perl/blog';

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

my $aws_creds = $config->{'aws_creds'};
my $dest = $config->{'blog_destination'};
my $bucket = $config->{'s3_bucket'};


my @fold_cmd = ("$fold_dir/fold_blog.pl");
push @fold_cmd, "-a" if defined $scope;
push @fold_cmd, "-c";
push @fold_cmd, $config_file;
push @fold_cmd, "-v" if defined $opt{'v'};

my $cmd = join(" ", @fold_cmd);

system($cmd) == 0 || die "Could not execute fold_blog.pl, $?";

my @rsync_cmd = ("rsync", "-arve", "'ssh -i", $aws_creds, "'", "--delete", "$blogging_dir/$blog_dir_name/*", $dest);


$cmd = join(" ", @rsync_cmd);

#print $cmd, "\n";

system($cmd) == 0 || die "Could not execute rsync, $?";

## AWS
my @aws_sync_cmd = ("aws", "s3", "sync", "$blogging_dir/$blog_dir_name", "s3://$bucket", "--delete", " --acl public-read");

my @all_but_shtml = ("--exclude='.git/*' --exclude='*.shtml'");
my @just_shtml = ("--exclude '*' --include '*.shtml' --no-guess-mime-type --content-type text/html");



$cmd = join(" ", @aws_sync_cmd, @all_but_shtml);
system($cmd) == 0 || die "Could not execute AWS sync, $?";

$cmd = join(" ", @aws_sync_cmd, @just_shtml);
system($cmd) == 0 || die "Could not execute AWS sync for shtml, $?";



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
