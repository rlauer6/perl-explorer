package Devel::Explorer::PodWriter;

# override of Pod::Html's resolve_page_link_method() to return all
# L<module> links as /pod/module-name

use strict;
use warnings;

use Pod::Html;
use Exporter;
use Readonly;

Readonly::Scalar our $URI_TEMPLATE => '/explorer/pod/%s';

our @ISA = qw(Exporter Pod::Html);

our @EXPORT_OK = qw(pod2html);

use File::Spec;

caller or __PACKAGE__->main();

no warnings 'redefine';  ## no critic (ProhibitNoWarnings)

########################################################################
sub main {
########################################################################
  my $module = shift @ARGV;
  
  my %options = (
    '--podpath'  => q{.},
    '--infile'   => $module,
    '--outfile'  => "$module.pod",
    '--cachedir' => File::Spec->tmpdir(),
  );

  pod2html( '--backlink', map { "$_=" . $options{$_} } keys %options );

  return;
}

########################################################################
# redefine resolve_pod_page_link()
########################################################################

package Pod::Simple::XHTML::LocalPodLinks;

use strict;
use warnings;

use base 'Pod::Simple::XHTML';

use File::Spec;
use File::Spec::Unix;

no warnings 'redefine';  ## no critic (ProhibitNoWarnings)

########################################################################
sub resolve_pod_page_link {
########################################################################
  my ( $self, $to, $section ) = @_;

  return
    if !$to && !$section;

  $to //= q{};

  $to =~ s/::/\//gxsm;

  if ( defined $section ) {
    $section = q{#} . $self->idify( $section, 1 );
  }

  $section //= q{};

  my $uri = sprintf $URI_TEMPLATE, $to, $section;
  
  return $to ? $uri : $section;
}

# original code below...
sub _resolve_pod_page_link {
  my ( $self, $to, $section ) = @_;

  return undef unless defined $to || defined $section;

  if ( defined $section ) {
    $section = q{#} . $self->idify( $section, 1 );
    return $section unless defined $to;
  }
  else {
    $section = '';
  }

  my $path;  # path to $to according to %Pages
  unless ( exists $self->pages->{$to} ) {
    # Try to find a POD that ends with $to and use that.
    # e.g., given L<XHTML>, if there is no $Podpath/XHTML in %Pages,
    # look for $Podpath/*/XHTML in %Pages, with * being any path,
    # as a substitute (e.g., $Podpath/Pod/Simple/XHTML)
    my @matches;
    foreach my $modname ( keys %{ $self->pages } ) {
      push @matches, $modname if $modname =~ /::\Q$to\E\z/;
    }

    if ( $#matches == -1 ) {
      warn "Cannot find \"$to\" in podpath: "
        . "cannot find suitable replacement path, cannot resolve link\n"
        unless $self->quiet;
      return '';
    }
    elsif ( $#matches == 0 ) {
      warn "Cannot find \"$to\" in podpath: " . "using $matches[0] as replacement path to $to\n"
        unless $self->quiet;
      $path = $self->pages->{ $matches[0] };
    }
    else {
      warn "Cannot find \"$to\" in podpath: "
        . "more than one possible replacement path to $to, "
        . "using $matches[-1]\n"
        unless $self->quiet;
      # Use [-1] so newer (higher numbered) perl PODs are used
      $path = $self->pages->{ $matches[-1] };
    }
  }
  else {
    $path = $self->pages->{$to};
  }

  my $url = File::Spec::Unix->catfile( Pod::Html::_unixify( $self->htmlroot ), $path );

  if ( $self->htmlfileurl ne '' ) {
    # then $self->htmlroot eq '' (by definition of htmlfileurl) so
    # $self->htmldir needs to be prepended to link to get the absolute path
    # that will be relativized
    $url = relativize_url(
      File::Spec::Unix->catdir( Pod::Html::_unixify( $self->htmldir ), $url ),
      $self->htmlfileurl  # already unixified
    );
  }

  return $url . ".html$section";
}

1;
