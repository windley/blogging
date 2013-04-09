#!/usr/bin/perl -w

use lib '/Users/pjw/prog/perl/blog';

use strict;
use utf8;

use Getopt::Std;
use File::Find;
use File::Path qw/make_path rmtree/;
use Data::Dumper;

use Blog qw/ :all /;

# global options
use vars qw/ %opt /;
my $opt_string = 'd:c:a';
getopts( "$opt_string", \%opt ) or usage();

die "No configuration file..." unless $opt{'c'};

my $config = read_config($opt{'c'});

my $entry_dir = "";
if ($opt{'d'} ) {
    $entry_dir = $opt{'d'} ;
} else {
    $entry_dir = $config->{'entry_dir'};
}

my $homepage_file = $config->{'target_home'}."/index.".$config->{'extension'};
my $rss_file = $config->{'target_home'}."/".$config->{'rss_file'};
my $index_file = $config->{'base_dir'}.$config->{'blog_id'}."/index.yml";

if ($opt{'a'}) {
  warn "Rebuilding all...";
  unlink $homepage_file;
  unlink $rss_file;
  unlink $index_file;
  warn "would remove ", $config->{'target_home'}."/".$config->{'tag_prefix'};
  warn "would remove ", $config->{'target_home'}."/".$config->{'path_prefix'};
}



# get the mtime of the homepage
my $homepage_mtime;
if (-e $homepage_file) {
  open(HOMEPAGE, $homepage_file);
  $homepage_mtime = (stat(HOMEPAGE))[9];
  close(HOMEPAGE);
} else {
  $homepage_mtime = 0;
}

my $index = read_index($index_file);


my($files);

find( sub{-f $_ and unshift @{ $files}, $File::Find::name;
         }, $entry_dir );


my $entry_count = 0;
my $homepage_meta = {
    'entries' => [],
    'blog_url' => $config->{'blog_url'},
    'blog_title' => $config->{'blog_title'},
    'blog_author' => $config->{'blog_author'},
    'blog_description' => $config->{'blog_description'},
    'year' => (localtime())[5] + 1900,
    'build_date' => scalar(localtime()),
};
my $rss_meta = {
    'entries' => [],
    'blog_url' => $config->{'blog_url'},
    'blog_title' => $config->{'blog_title'},
    'blog_author' => $config->{'blog_author'},
    'blog_description' => $config->{'blog_description'},
    'year' => (localtime())[5] + 1900,
    'build_date' => scalar(localtime()),
};
my $touched = {};

warn "Rebuilding entries";
foreach my $f (@{$files}) {

  my ($meta) = make_blog_entry($f, $config);
  next if($meta->{'status'} eq "draft");

  $index = index_entry($index, $meta);

  # using mtime for homepage as indication of what needs updating
  if ($meta->{'mtime'} > $homepage_mtime || $opt{'a'}) {
    # warn $f;
    output_blog_file($config, $meta);

    foreach my $kw (split(/,\s*/,$meta->{'keywords'})) {
      $touched->{'keywords'}->{$kw} = 1;
    }

    $touched->{'archives'}->{$meta->{'archive'}} = 1;
  }

  if ($entry_count < $config->{'homepage_entries'}) {
    push(@{ $homepage_meta->{'entries'} }, $meta);
    push(@{ $rss_meta->{'entries'} }, $meta);
  } else {
    last unless $opt{'a'};
  }

  $entry_count++;

}

# print Dumper $index;
write_index($index_file, $index);

# output recents
my $recents_file = $config->{'target_home'}."/inc/".$config->{'includes'}->{'recents'};
open(RECENTS, '>', $recents_file);
print RECENTS <<_EOF_;
<h3>From the Home Page</h3>
<ul>
_EOF_

my $recent_count = 0;
foreach my $entry (@{ $homepage_meta->{'entries'} }) {
   print RECENTS "  <li><a href='$entry->{entry_url}'>$entry->{title}</a></li>\n";
   $recent_count++;
   last if ($recent_count > $config->{'recent_entries'});
}
print RECENTS "</ul>";
close(RECENTS);


# print hompage
warn "Printing homepage...";
my $homepage = $config->{'homepage_template_file'}->fill_in(HASH => $homepage_meta);
if ($homepage) {
  open(HOMEPAGE, '>', $homepage_file);
  print HOMEPAGE $homepage;
  close(HOMEPAGE);
} else {
  die  "Couldn't fill in template: $Text::Template::ERROR" 
}

# print rss page
warn "Printing $rss_file";
my $rss = $config->{'rss_template_file'}->fill_in(HASH => $rss_meta);
open(RSS, '>', $rss_file);
print RSS $rss;
close(RSS);

# do archives (creates multiple files including inc file)
warn "Processing archive files...";
output_archive_files($config, $index, $touched);

warn "Processing keyword files...";
output_keyword_files($config, $index, $touched);

warn "Creating tagcloud...";
output_tagcloud($config, $index);

1;


#
# Message about this program and how to use it
#
sub usage {
    print STDERR << "EOF";

Formats blog enties.

usage: $0 [-h?] -f individual_entry

 -h|?      : this (help) message
 -c file   : configuration file
 -d dir    : directory holding blog entries

example: $0 -d "2013/02/23/131456.html"

EOF
    exit;
}
