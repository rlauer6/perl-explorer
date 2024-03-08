package Devel::Explorer::ToDo;

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
use File::Temp             qw(tempfile);
use English                qw(-no_match_vars);
use List::Util             qw(pairs);

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
    qw(
      config
      module
      todos
      explorer
    )
);

use parent qw(Exporter Class::Accessor::Fast);

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
    my ( $class, @args ) = @_;

    my $options = ref $args[0] ? $args[0] : {@args};

    my $self = $class->SUPER::new($options);

    $self->set_defaults;

    return $self;
}

########################################################################
sub set_defaults {
########################################################################
    my ($self) = @_;

    my $config = $self->get_config;

    $self->set_config( $config // {} );

    die "explorer is a required argument\n"
      if !$self->get_explorer;

    $self->_validate_todo_list;

    $self->_validate_module;

    return $self;
}

########################################################################
sub _validate_module {
########################################################################
    my ($self) = @_;

    my $module = $self->get_module;

    die "no module\n"
      if !$module;

    die "module ($module) not found\n"
      if !defined $self->get_explorer->has_pod($module);

    return $TRUE;
}

########################################################################
sub _validate_todo_list {
########################################################################
    my ($self) = @_;

    my @todos = @{ $self->get_todos };

    die "no todos\n"
      if !@todos;

    die "odd number of elements in todos, should be line/policy pairs\n"
      if @todos % 2;

    foreach my $todo ( pairs @todos ) {
        my ( $line, $policy ) = @{$todo};

        die "not a line number ($line)\n",
          if $line !~ /^\d+$/xsm;

        die "$policy doesn't look like a policy\n"
          if $policy !~ /::/xsm;
    }

    return $TRUE;
}

########################################################################
sub save_todos {
########################################################################
    my ($self) = @_;

    my $todos    = $self->get_todos;
    my $explorer = $self->get_explorer;
    my $module   = $self->get_module;

    my @source = fetch_source_from_module(
        explorer => $explorer,
        module   => $module,
    );

    my %source_map;

    foreach my $todo ( pairs @{$todos} ) {
        my ( $linenum, $policy ) = @{$todo};

        $source_map{$linenum} //= [];

        push @{ $source_map{$linenum} }, $policy;
    }

    foreach my $linenum ( keys %source_map ) {
        my %policy_list  = map { $_ => 1 } @{ $source_map{$linenum} };
        my $todo_comment = sprintf ' ## no critic ( %s )', join "$COMMA ", keys %policy_list;

        my $source_line = $source[ $linenum - 1 ];

        # remove existing TODOs
        $source_line =~ s/(\s[#][#]\sno\scritic.*$)//xsm;

        $source[ $linenum - 1 ] = "${source_line}$todo_comment";
    }

    my $commented_source = join "\n", @source;

    my $file = $explorer->get_module_path($module);

    replace_file( infile => $file, source => $commented_source );

    return $TRUE;
}

########################################################################
sub main {
########################################################################

    return 0;
}

1;

__END__

=pod

=head1 NAME

Devel::Explorer::ToDo

=head1 SYNOPSIS 

=head1 DESCRIPTION

=head1 METHODS AND SUBROUTINES

=head1 SEE OTHER

=head1 AUTHOR

=cut
