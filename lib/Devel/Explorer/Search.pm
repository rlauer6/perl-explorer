package Devel::Explorer::Search;

use strict;
use warnings;

use Devel::Explorer::Utils qw(:all);
use English qw(-no_match_vars);
use File::Find;
use Scalar::Util qw(reftype);
use List::Util qw(uniq);
use HTML::Escape qw(escape_html);
use Syntax::SourceHighlight;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(anchored explorer source namespace));

use parent qw(Devel::Explorer::Base);

caller or __PACKAGE__->main();

########################################################################
sub search {
########################################################################
  my ( $self, @args ) = @_;

  my $options = get_args(@args);

  my ( $source, $file, $regexp, $text, $exact_match, $anchored )
    = @{$options}{qw(source file regexp text exact_match anchored)};

  die "nothing to search\n"
    if !$text && !$regexp;

  $anchored //= $self->get_anchored;
  $text     //= $EMPTY;

  if ($text) {
    $regexp = $anchored ? qr/^$text$/ixsm : qr/$text/ixsm;
  }
  else {
    if ( reftype($regexp) ne 'REGEXP' ) {
      if ( $regexp !~ /^qr/xsm ) {
        $regexp = "qr$regexp";
      }

      $regexp = eval "$regexp";  ## no critic
    }

    die "not a valid regexp\n"
      if !$regexp || reftype($regexp) ne 'REGEXP';
  }

  my @source_lines;

  my $ext = $EMPTY;

  if ($file) {
    @source_lines = slurp_file($file);

    if ( $file =~ /([.][^.]+)$/xsm ) {
      $ext = $1;
    }
  }
  else {
    $source //= $self->get_source;

    die "no source\n"
      if !$source;

    @source_lines = ref $source ? @{$source} : split /\n/xsm, $source;
  }

  my $linenum = 0;
  my @results;

  dbg
    regexp => $regexp,
    text   => $text,
    source => \@source_lines;

  foreach my $line (@source_lines) {
    ++$linenum;
    next if $line !~ /$regexp/;  ## no critic

    $line = highlight_line( $line, $ext );

    push @results, [ $linenum, $line ];
  }

  return \@results;
}

{
  my $highlighter;

########################################################################
  sub highlight_line {
########################################################################
    my ( $line, $ext ) = @_;

    return $line
      if !$ext || !$SOURCE_HIGHLIGHT_MAP{$ext};

    $highlighter //= Syntax::SourceHighlight->new('htmlcss.outlang');

    my $highlighted_line = $highlighter->highlightString( $line, $SOURCE_HIGHLIGHT_MAP{$ext} );
    $highlighted_line =~ s/<!--.*-->//xsm;
    $highlighted_line =~ s/^<pre>/<pre class="pe-highlighted-line">/xsm;

    return $highlighted_line;
  }
}

########################################################################
sub search_all {
########################################################################
  my ( $self, @args ) = @_;

  my $options = get_args(@args);

  my ( $namespace, $text, $explorer, $regexp, $callback )
    = @{$options}{qw(namespace text explorer regexp callback)};

  $explorer  //= $self->get_explorer;
  $namespace //= $self->get_namespace;

  die "explorer is required\n"
    if !$explorer;

  my $file_info = $explorer->get_file_info;

  my @ids;

  my ( $modules_only, $scripts_only ) = @{$options}{qw(modules_only scripts_only)};

  if ($modules_only) {
    my $modules = $explorer->get_modules;

    @ids = uniq values %{$modules};

    if ($namespace) {
      @ids = uniq map { /^${namespace}::/xsm ? $modules->{$_} : () } keys %{$modules};
    }
  }
  elsif ($scripts_only) {
    @ids = map { $file_info->{$_}->{ext} eq '.pl' } keys %{$file_info};
  }
  else {
    @ids = keys %{$file_info};
  }

  my %compiled_results;

  my @file_list = $explorer->get_file_by_id( \@ids );

  foreach my $file (@file_list) {

    my $results = $self->search(
      file   => $file,
      text   => $text,
      regexp => $regexp
    );

    next if !@{$results};
    $compiled_results{$file} //= [];

    foreach my $line ( @{$results} ) {
      push @{ $compiled_results{$file} }, $line;
    }

    next if !$callback;

    $callback->( $file, \%compiled_results );  # add your stuff if you want
  }

  return \%compiled_results;
}

########################################################################
sub main {
########################################################################

  my $text      = shift @ARGV;
  my $namespace = shift @ARGV;

  die "TODO: this won't work with out a configuration file\n";

  my $explorer = Devel::Explorer->new();

  die "usage: $PROGRAM_NAME path text [namespace]\n"
    if !$text;

  my $search = __PACKAGE__->new();

  dbg results => $search->search_all(
    regexp    => qr/$text/xsmi,
    explorer  => $explorer,
    namespace => $namespace
  );

  return 0;
}

1;
