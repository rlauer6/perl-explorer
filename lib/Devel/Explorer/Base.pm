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
use English qw(-no_match_vars);

use parent qw(Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw(
      skip_defaults
      config
      config_file
      template_name
    )
);

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
    my ( $class, @args ) = @_;

    my $options = ref $args[0] ? $args[0] : {@args};

    my $self = $class->SUPER::new($options);

    if ( !$self->get_skip_defaults ) {
        $self->set_defaults;
    }

    return $self;
}

########################################################################
sub verify_template {
########################################################################
    my ( $self, $name ) = @_;

    my $template = $self->get_template;
    my $config   = $self->get_config;

    if ( !$template ) {
        $template = $config->{templates}->{$name};

        die "no such template ($name) found in configuration\n"
          if !$template;
    }
    elsif ( $template =~ /pe-explorer-([^.]+)[.]html/xsm ) {
        $name = $1;
    }

    $self->set_template_name($name);

    die "unable to find template ($template)\n"
      if !-e $template;

    $self->set_template($template);

    return;
}

########################################################################
sub render {
########################################################################
    my ( $self, @args ) = @_;

    my $options = get_args(@args);
    my ( $config, $template, $template_name, $params )
      = @{$options}{qw(config template template_name params)};

    $config   //= $self->get_config;
    $template //= $self->get_template;

    $template_name //= $self->get_template_name;

    if ( !$template ) {
        $template_name //= $self->get_template_name;
        $template = sprintf 'pe-explorer-%s.html.tt', $template_name;
    }
    elsif ( !$template_name ) {
        if ( $template =~ /pe-explorer-([^.]+)[.]html/xsm ) {
            $template_name = $1;
        }
    }

    my $html = slurp_file $template;

    $params->{js}  //= fix_path( $config->{site}->{js},  $config->{critic}->{js} );
    $params->{css} //= fix_path( $config->{site}->{css}, $config->{critic}->{css} );

    return tt_process( $html, $params );
}

########################################################################
sub set_defaults {
########################################################################
    my ($self) = @_;

    return $self;
}

1;
