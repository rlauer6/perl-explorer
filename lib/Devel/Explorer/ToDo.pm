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
use Text::Wrap;
use Readonly;

Readonly::Scalar our $DEFAULT_MAX_TODO_LENGTH => 72;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
    qw(
      config
      no_critic
      module
      todos
      wrap_columns
      explorer
    )
);

use parent qw(Devel::Explorer::Base);

caller or __PACKAGE__->main();

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

    $self->set_wrap_columns( $self->get_wrap_columns || $DEFAULT_MAX_TODO_LENGTH );

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
        $line =~ s/\D//;

        die "not a line number ($line)\n",
          if !$line;

        next
          if !$self->get_no_critic;

        die "$policy doesn't look like a policy\n"
          if $policy !~ /::/xsm;
    }

    return $TRUE;
}

########################################################################
sub save_todos {
########################################################################
    my ( $self, $no_critic ) = @_;

    $no_critic //= $self->get_no_critic;

    my $todos    = $self->get_todos;
    my $explorer = $self->get_explorer;
    my $module   = $self->get_module;

    my @source = fetch_source_from_module(
        explorer => $explorer,
        module   => $module,
    );

    dbg todos => $todos;

    my %source_map;

    foreach my $todo ( pairs @{$todos} ) {
        my ( $linenum, $todo_text ) = @{$todo};
        $linenum =~ s/\D//xsmg;

        $source_map{$linenum} //= [];

        push @{ $source_map{$linenum} }, $todo_text;
    }

    my $commented_source = $EMPTY;

    if ($no_critic) {

        foreach my $linenum ( keys %source_map ) {
            my %policy_list  = map { $_ => 1 } @{ $source_map{$linenum} };
            my $todo_comment = sprintf ' ## no critic ( %s )', join "$COMMA ", keys %policy_list;

            my $source_line = $source[ $linenum - 1 ];

            # remove existing TODOs
            $source_line =~ s/(\s[#][#]\sno\scritic.*$)//xsm;

            $source[ $linenum - 1 ] = "${source_line}$todo_comment";
        }

        $commented_source = join "\n", @source;
    }
    else {
        local $Text::Wrap::columns = $self->get_wrap_columns;

        %source_map = map { $_ + 0 => $source_map{$_} } keys %source_map;

        dbg source_map => \%source_map;

        foreach my $linenum ( 1 .. @source ) {
            if ( $source_map{$linenum} ) {

                my $comment = join $SPACE, @{ $source_map{$linenum} };
                $comment =~ s/\n/ /xsmg;
                $comment = wrap( '## TODO: ', '## ', $comment );
                $commented_source .= sprintf "%s\n%s\n", $comment, $source[ $linenum - 1 ];
            }
            else {
                $commented_source .= sprintf "%s\n", $source[ $linenum - 1 ];
            }
        }
    }

    my $file = $explorer->get_module_path($module);

    return $FALSE
      if !$commented_source;

    replace_file( infile => $file, source => $commented_source );

    return $TRUE;
}

########################################################################
sub main {
########################################################################

    return 0;
}

1;
