package Devel::Explorer::Base;

use strict;
use warnings;

BEGIN {
  my $home = $ENV{HOME};

  if ($home) {
    my @lib = ( 'lib', sprintf '%s/lib/perl5', $home );

    use lib @lib;
  }
}

use Data::Dumper;
use Devel::Explorer::Utils qw(:all);
use English                qw(-no_match_vars);

use parent qw(Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    config
    config_file
  )
);

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
  my ( $class, @args ) = @_;

  my $options = ref $args[0] ? $args[0] : {@args};

  my $self = $class->SUPER::new($options);

  my $config = $self->init_config;

  $self->set_defaults;

  return $self;
}

########################################################################
sub verify_template {
########################################################################
  my ( $self, $default_template ) = @_;

  my $template = $self->get_template;
  my $config   = $self->get_config;

  if ( !$template ) {
    $template = sprintf '%s/%s', $config->{templates}->{$default_template};
  }

  die "unable to find template ($template)\n"
    if !-e $template;

  $self->set_template($template);

  return;
}

########################################################################
sub set_defaults {
########################################################################
  my ($self) = @_;

  return $self;
}

1;
