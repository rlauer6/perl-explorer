#!/usr/bin/perl

use strict;
use warnings;

package Devel::Explorer::Configure;

use English qw(-no_match_vars);
use Template;
use Devel::Explorer::Utils qw(:all);
use Carp;
use Cwd;

use Readonly;
use JSON;

Readonly::Scalar our $DEFAULT_CONFIG  => 'defaults.json';
Readonly::Scalar our $DEFAULT_LIBDIR  => '/explorer';
Readonly::Scalar our $DEFAULT_DATADIR => '/usr/local/share/perl-explorer';
Readonly::Scalar our $DEFAULT_SITEDIR => '/var/www';
Readonly::Scalar our $DEFAULT_PORT    => '8080';

use parent qw(CLI::Simple);

caller or __PACKAGE__->main();

########################################################################
sub init {
########################################################################
  my ($self) = @_;

  return $TRUE;
}

########################################################################
sub configure {
########################################################################
  my ($self) = @_;

  croak "--repo is a required argument\n"
    if !$self->get_repo;

  my $cwd = getcwd;

  my $config_file = $self->get_config // 'defaults.json';

  die "no config file\n"
    if !-e $config_file;

  my $config = eval { slurp_json($config_file); };

  die "unable to read $config_file\n$EVAL_ERROR"
    if !$config;

  foreach (qw(defaults config_template files)) {
    die "no $_ defined in config file\n"
      if !$config->{$_};
  }

  my $file_list = $config->{files};
  my $defaults  = $config->{defaults};

  my $params = {
    defaults => {
      libdir  => $self->get_libdir  // $defaults->{libdir},
      sitedir => $self->get_sitedir // $defaults->{sitedir},
      repo    => $self->get_repo    // $defaults->{repo},
      datadir => $self->get_datadir // $defaults->{datadir},
      port    => $self->get_port    // $defaults->{port},
    }
  };

  my $template   = slurp_file( $config->{config_template} );
  my $new_config = tt_process( $template, $params );
  $new_config = JSON->new->decode($new_config);
  $new_config->{defaults} = $params->{defaults};

  $self->save( $file_list->{ $config->{config_template} }, $new_config );

  foreach my $template_file ( keys %{$file_list} ) {
    my $template = slurp_file($template_file);
    $template =~ s/^[#][^\n]*\n//xsmg;

    my $dest = $file_list->{$template_file};
    $self->save( $dest, tt_process( $template, $new_config ) );
  }

  return 0;
}

########################################################################
sub save {
########################################################################
  my ( $self, $file, $content ) = @_;

  create_backup($file);

  if ( ref $content ) {
    $content = JSON->new->pretty($TRUE)->encode($content);
  }

  open my $fh, '>', $file
    or croak "could not open $file for writing\n$OS_ERROR";

  print {$fh} $content;

  return close $fh;
}

########################################################################
sub main {
########################################################################

  my @option_specs = qw(
    help
    repo|r=s
    sitedir=s
    libdir=s
    datadir=s
    config=s
    port=s
    replace|R
  );

  Getopt::Long::Configure('no_ignore_case');

  return __PACKAGE__->new(
    option_specs    => \@option_specs,
    extra_options   => [],
    default_options => {
      sitedir => $DEFAULT_SITEDIR,
      libdir  => $DEFAULT_LIBDIR,
      datadir => $DEFAULT_DATADIR,
      port    => $DEFAULT_PORT,
      config  => $DEFAULT_CONFIG,
    },
    commands => { configure => \&configure, },
  )->run;
}

exit main();

1;
