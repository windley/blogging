package Blog;
use strict;
#use warnings;


use Getopt::Std;
use Text::Template;
use YAML::XS;
use Date::Parse;
use File::Find;
use File::Path qw/make_path rmtree/;
use HTML::Strip;
use HTML::Entities;
use HTML::TagCloud;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use utf8;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);


our $VERSION     = 1.00;
our @ISA         = qw(Exporter);

our %EXPORT_TAGS = (all => [
qw(
read_config
make_blog_entry
output_blog_file
output_archive_files
output_keyword_files
output_tagcloud
read_index
write_index
index_entry
) ]);
our @EXPORT_OK   =(@{ $EXPORT_TAGS{'all'} }) ;



use constant DEFAULT_CONFIG_FILE => './config.yml';
use constant DEFAULT_INDEX_FILE => './ixdex.yml';


my @month_name = qw(Jan Feb Mar Apr May Jun Jul Aug Sept Oct Nov Dec);

our $config;
sub read_config {
    my ($filename) = @_;

    $filename ||= DEFAULT_CONFIG_FILE;

#    print "File ", $filename;
    my $config;
    if ( -e $filename ) {
      $config = YAML::XS::LoadFile($filename) ||
	warn "Can't open configuration file $filename: $!";
    }

    my $base_dir = $config->{'base_dir'}.$config->{'blog_id'};
    $config->{'entry_dir'} = $base_dir."/entries/";
    $config->{'include_dir'} = $base_dir."/inc/";
    $config->{'template_dir'} = $base_dir."/templates/";

    $config->{'individual_entry_template_file'} = 
      Text::Template->new(SOURCE => $config->{'template_dir'}.$config->{'templates'}->{'individual_entry'})
	  or die "Couldn't construct template: $Text::Template::ERROR";
    $config->{'homepage_template_file'} = 
      Text::Template->new(SOURCE => $config->{'template_dir'}.$config->{'templates'}->{'homepage'})
	  or die "Couldn't construct template: $Text::Template::ERROR";
    $config->{'rss_template_file'} = 
      Text::Template->new(SOURCE => $config->{'template_dir'}.$config->{'templates'}->{'rss'})
	  or die "Couldn't construct template: $Text::Template::ERROR";
    $config->{'archive_template_file'} = 
      Text::Template->new(SOURCE => $config->{'template_dir'}.$config->{'templates'}->{'archive'})
	  or die "Couldn't construct template: $Text::Template::ERROR";
    $config->{'keyword_template_file'} = 
      Text::Template->new(SOURCE => $config->{'template_dir'}.$config->{'templates'}->{'keyword'})
	  or die "Couldn't construct template: $Text::Template::ERROR";

    return $config;
}

sub make_blog_entry {

  my($entry_file, $config) = @_;

  my $meta = compute_meta($entry_file, $config);

#  warn $meta->{'status'}, " ", $meta->{'timestamp'} if $meta->{'status'} eq 'draft';

  #print Dumper($meta);
  my $result = $config->{'individual_entry_template_file'}->fill_in(HASH => $meta);
  
  unless (defined $result) {
    die "Couldn't fill in template: $Text::Template::ERROR" 

  }

  $meta->{'result'} = $result;
  return($meta);
}

sub output_blog_file {
  my($config, $meta) = @_;
  # make sure directory exists
  my $directory = $config->{'target_home'}.$meta->{'entry_dir'};
  unless (-d $directory ) {
    make_path($directory);
  }

  open(OUT, '>', $directory.$meta->{'filename'});
  print OUT $meta->{'result'};
  close(OUT);
}


sub compute_meta {
  my($entry_file, $config) = @_;
  my $meta = {'blog_url' => $config->{'blog_url'},
	     };


  # since meta vars in the entry can be multi-line, we have a little state machine here
  my $in_meta = 0;
  my $meta_type = "";
  my $line;
  open(ENTRY,$entry_file) or die $!;

  $meta->{'mtime'} = (stat(ENTRY))[9];
  $meta->{'timestamp'} = localtime($meta->{'mtime'});

  my $ext = ".".$config->{'extension'};
  my $path_prefix = "/".$config->{'path_prefix'};

  while ($line = <ENTRY>) {
    #  print "$line";
    if ($in_meta) {

      if ($line =~ m/-->/) {
	$in_meta = 0;
	next;
      } 

      $meta->{$meta_type} .= $line;
    
    } elsif ($line =~ m/^<!--/) {

      $in_meta = 1;
      ($meta_type = $line) =~ s/<!--\s+(\w+):.*$/$1/s;

      if ($line =~ m/-->/) {
	(my $content = $line) =~ s/^.*:\s+(.*)\s+-->$/$1/s;
	$meta->{$meta_type} .= $content;
	$in_meta = 0;
      }
    
    } else {
      $meta_type = "body";
      $meta->{$meta_type} .= $line;
      $in_meta = 0;
    }

  }

  close(ENTRY);

  warn "$entry_file produced empty meta" unless $meta->{'title'};

  chomp($meta->{'title'});


  # compute the filename
  ($meta->{'filename'} = $meta->{'title'}) =~ s/[\r\n]+//g;
  $meta->{'filename'} =~ s/\s$//g;
  $meta->{'filename'} =~ s/\s/_/g;
  $meta->{'filename'} =~ s/[^A-Za-z0-9-_]//g;
  $meta->{'filename'} = lc($meta->{'filename'}).$ext;

  # throw it all away if the base_name overrides
  if (defined $meta->{'base_name'}) {
    $meta->{'base_name'} =~ s/[\r\n]+//g;
    $meta->{'filename'} = $meta->{'base_name'}.$ext;
  }

  # some excerpts have newlines that should be spaces
  $meta->{'excerpt'} =~ s/[\r\n]+/ /g;

  # want it to be empty if it's empty
  $meta->{'excerpt'} =~ s/\s*$//g;
  $meta->{'excerpt'} =~ s/\\n//g; # some got an escaped newline

  # want it to be empty if it's empty
  if (defined $meta->{'postimage'}) {
    $meta->{'postimage'} =~ s/\s*$//g;
    $meta->{'postimage'} =~ s/\\n//g; # some got an escaped newline
  }


  $meta->{'keywords'} =~ s/[\s\r\n]+//g;
  $meta->{'keywords'} =~ s/\\n//g; # some got an escaped newline
  $meta->{'keywords'} =~ s/[^a-zA-Z0-9_+,.-]//g; # some got an escaped newline
  $meta->{'keywords'} = lc($meta->{'keywords'}); # make all keywords lowercase


  $meta->{'body'} =~ s/\222/'/g;
  $meta->{'body'} =~ s/[\223\224]/"/g;
  $meta->{'body'} =~ s/\227/--/g;

  # default to date, but use timestamp otherwise
  if (defined $meta->{'date'}) {
    # like this format better
    $meta->{'timestamp'} = localtime(str2time($meta->{'date'}));
  } else {
    $meta->{'date'} = $meta->{'timestamp'};
  }

  $meta->{'time'} = str2time($meta->{'date'});

  #  warn $meta->{'timestamp'};

  # for path
  my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($meta->{'timestamp'});
  $year = $year + 1900;
  $month = sprintf("%02d",$month+1);
  $day = sprintf("%02d",$day);
  #warn join (":",($ss,$mm,$hh,$day,$month,$year,$zone));
  $meta->{'entry_dir'} = "$path_prefix/$year/$month/";
  $meta->{'archive'} = "$year|$month";
  $meta->{'entry_url'} = $meta->{'entry_dir'} . $meta->{'filename'};
#  warn $meta->{'entry_url'};

  # if ($meta->{'entry_url'} eq "/archives/2002/06/egovernment_on.shtml") {
  #    warn $meta->{'body'};
  # }

  $meta->{'status'} = 'publish' unless(defined  $meta->{'status'});
  $meta->{'status'} =~ s/[\s\r\n]+//g;

  return $meta;
}

sub read_index {
    my ($filename) = @_;

    $filename ||= DEFAULT_INDEX_FILE;
    my $index;
    if ( -e $filename ) {
      $index = YAML::XS::LoadFile($filename) ||
	warn "Can't open index file $filename: $!";
    }

    return $index;
}

sub write_index {
    my ($filename, $index) = @_;

#    warn $filename;
    $filename ||= DEFAULT_INDEX_FILE;
    YAML::XS::DumpFile($filename, $index) ||
	warn "Can't open index file $filename: $!";
}

sub index_entry {
   my($index, $meta) = @_;

   # create the main entry
   $index->{$meta->{'entry_url'}}->{'title'} = $meta->{'title'};
   $index->{$meta->{'entry_url'}}->{'timestamp'} = $meta->{'timestamp'};
   $index->{$meta->{'entry_url'}}->{'entry_url'} = $meta->{'entry_url'};
   if ($meta->{'excerpt'}) {
     $index->{$meta->{'entry_url'}}->{'excerpt'} = $meta->{'excerpt'};
   } else {
#     warn $meta->{'entry_url'};
     $index->{$meta->{'entry_url'}}->{'excerpt'} = make_excerpt($meta->{'body'});
   }
   
   # create cross-references for the monthly archives
   $index->{'archives'}->{$meta->{'archive'}}->{'entries'}->{$meta->{'time'}} = $meta->{'entry_url'};

   # create the cross-references for the keywords
   foreach my $kw (split(/,\s*/,$meta->{'keywords'})) {
     $index->{'keywords'}->{$kw}->{'entries'}->{$meta->{'time'}} = $meta->{'entry_url'};
   }
   return $index;
}

sub make_excerpt {
  my($text) = @_;

  my $hs = HTML::Strip->new(emit_spaces=>0);
  $hs->set_decode_entities(0);
  my $clean_text = $hs->parse( $text );
  $hs->eof;

  # get first 100 words
  my $num_words=100;
  my @text_array = split(/\s+/, $clean_text);
  $num_words = scalar(@text_array) if (scalar(@text_array) < $num_words);
  my $shortened_text = join(' ', @text_array[0..$num_words-1]);
  $shortened_text =~ s/\s*$//g;
  $shortened_text =~ s/&nbsp;/ /g;
  $shortened_text =~ s/Image via Wikipedia //g;

#  warn $shortened_text;
   
  return $shortened_text;
}


sub output_archive_files {
  my($config, $index, $touched, $verbose) = @_;

  my $archives_inc_file = $config->{'target_home'}."/inc/".$config->{'includes'}->{'archives'};

  print "Processing archive file $archives_inc_file\n" if $verbose;
  open(ARCHIVES, '>', $archives_inc_file);

  print ARCHIVES <<_EOF_;
<!-- Modal -->
<div id="ArchiveModal" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="ArchiveModalLabel" aria-hidden="true">
  <div style="background-color: #6FA8DC; color: #FFFFFF" class="modal-header">
    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
    <h1 id="ArchiveModalLabel">Archives</h1>
  </div>
  <div class="modal-body"><ul>
_EOF_

  foreach my $archive (reverse sort keys %{ $index->{'archives'} }) {
    my($year, $month) = split(/\|/, $archive);
    my $archive_link = "/$config->{'path_prefix'}/$year/$month/";
    my $mn = $month_name[$month-1];

    print ARCHIVES <<_EOF_;
    <li><a tabindex="-1" href="$archive_link">$mn $year</a></li>
_EOF_
  }

  print ARCHIVES <<_EOF_;
  </ul>
  </div>
<!--
  <div class="modal-footer">
    <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
  </div>
-->
</div>
_EOF_

  close(ARCHIVES);

  for my $arc (sort keys %{$touched->{'archives'}}) {
    warn "updating $arc" if $verbose;

    my($year, $month) = split(/\|/, $arc);
    my $archive_file = $config->{'target_home'}."/$config->{'path_prefix'}/$year/$month/index.".$config->{'extension'};
    


    my $archive_meta = {'entries' => [],
			'month' => $month_name[$month-1],
			'year' => $year,
		       };

    for my $archive_data (sort keys %{ $index->{'archives'}->{$arc}->{'entries'} }) {
      my $url = $index->{'archives'}->{$arc}->{'entries'}->{$archive_data};
      unshift(@{ $archive_meta->{'entries'} }, $index->{$url});
    }

    $archive_meta->{'count'} = scalar (@{ $archive_meta->{'entries'} });

    my $archive = $config->{'archive_template_file'}->fill_in(HASH => $archive_meta);
    if ($archive) {
#      warn "writing $archive_file";
      open(ARCHIVE, '>', $archive_file);
      print ARCHIVE $archive;
      close(ARCHIVE);
    } else {
      die  "Couldn't fill in template: $Text::Template::ERROR" 
    }
  }
}


sub output_keyword_files {
  my($config, $index, $touched) = @_;

  my $directory = $config->{'target_home'}."/".$config->{'tag_prefix'};
  unless (-d $directory ) {
    make_path($directory);
  }

  for my $kw (sort keys %{$touched->{'keywords'}}) {
#    warn "updating $kw";

    my $keyword_file = "$directory/$kw.".$config->{'extension'};
    
    my $keyword_meta = {'entries' => [],
			'keyword' => $kw
		       };

    for my $keyword_data (sort keys %{ $index->{'keywords'}->{$kw}->{'entries'} }) {
      my $url = $index->{'keywords'}->{$kw}->{'entries'}->{$keyword_data};
      unshift(@{ $keyword_meta->{'entries'} }, $index->{$url});
    }

    $keyword_meta->{'count'} = scalar (@{ $keyword_meta->{'entries'} });

    my $keyword = $config->{'keyword_template_file'}->fill_in(HASH => $keyword_meta);
    if ($keyword) {
#      warn "writing $keyword_file with $keyword_meta->{'count'} entries";
      open(KEYWORD, '>', $keyword_file);
      print KEYWORD $keyword;
      close(KEYWORD);
    } else {
      die  "Couldn't fill in template: $Text::Template::ERROR" 
    }
  }
}

sub output_tagcloud {
  my($config, $index) = @_;

  my $tag_directory = "/".$config->{'tag_prefix'};

  my $cloud = HTML::TagCloud->new();

  for my $kw (sort keys %{ $index->{'keywords'} }) {

    my $keyword_url = "$tag_directory/$kw.".$config->{'extension'};

    my $count = scalar(keys %{ $index->{'keywords'}->{$kw}->{'entries'} });

    $cloud->add($kw, $keyword_url, $count);

  }

  my $tagcloud_inc_file = $config->{'target_home'}."/inc/".$config->{'includes'}->{'tagcloud'};
  open(TAGCLOUD, '>', $tagcloud_inc_file);
  print TAGCLOUD <<_EOF_;
<!-- Modal -->
<div id="TagModal" class="modal hide fade" tabindex="-1" role="dialog" aria-labelledby="TagModalLabel" aria-hidden="true">
  <div style="background-color: #6FA8DC; color: #FFFFFF" class="modal-header">
    <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
    <h1 id="TagModalLabel">Top $config->{'tagcloud_entries'} Tags</h1>
  </div>
  <div class="modal-body">
_EOF_

  print TAGCLOUD $cloud->html($config->{'tagcloud_entries'});

  print TAGCLOUD <<_EOF_;
  </div>
<!--
  <div class="modal-footer">
    <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
  </div>
-->
</div>
_EOF_

  close(TAGCLOUD);

  my $tagcloud_css_file = $config->{'target_home'}."/css/".$config->{'css'}->{'tagcloud'};
  open(TAGCLOUD, '>', $tagcloud_css_file);
  print TAGCLOUD $cloud->css();
  close(TAGCLOUD);

}

1;
