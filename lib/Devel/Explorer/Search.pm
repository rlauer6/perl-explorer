package Devel::Explorer::Search;

use strict;
use warnings;

use Devel::Explorer::Utils qw(:all);
use English                qw(-no_match_vars);
use File::Find;
use Scalar::Util qw(reftype);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(modules package_names anchored explorer source));

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

    my @source_lines;

    if ($file) {
        @source_lines = slurp_file($file);
    }
    else {
        $source //= $self->get_source;

        die "no source\n"
          if !$source;

        @source_lines = ref $source ? @{$source} : split /\n/xsm, $source;
    }

    my $linenum = 0;
    my @results;

    foreach my $line (@source_lines) {
        ++$linenum;
        next if $line !~ /$regexp/xsm;

        push @results, [ $linenum, $line ];
    }

    return \@results;
}

########################################################################
sub find_modules {
########################################################################
    my ( $self, $path ) = @_;

    my @modules;

    find(
        sub {
            return if !/[.]pm$/xsm;
            push @modules, $File::Find::name;
        },
        $path
    );

    my %paths;

    foreach my $module (@modules) {
        my $module_path = $module;

        $module =~ s/$path\///xsm;
        $module =~ s/\//$DOUBLE_COLON/xsmg;
        $module =~ s/[.]pm$//xsm;
        $paths{$module_path} = $module;
    }

    return \%paths;
}

########################################################################
sub search_all {
########################################################################
    my ( $self, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $namespace, $text, $path, $modules, $regexp, $callback )
      = @{$options}{qw(explorer namespace text path modules regexp callback)};

    if ( !$modules ) {
        if ($explorer) {
            $modules = $explorer->get_modules;
        }
        else {

            die "no path\n"
              if !$path;

            $modules //= $self->find_modules($path);
        }
    }

    my @file_list = keys %{$modules};

    my %package_names = reverse %{$modules};

    if ($namespace) {
        @file_list = map { /^${namespace}::/xsm ? $package_names{$_} : () } keys %package_names;
    }

    my %compiled_results;

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

    my $path      = shift @ARGV;
    my $text      = shift @ARGV;
    my $namespace = shift @ARGV;

    die "usage: $PROGRAM_NAME path text [namespace]\n"
      if !$path || !$text;

    my $search = __PACKAGE__->new();

    dbg results => $search->search_all(
        regexp    => qr/$text/xsmi,
        path      => $path,
        namespace => $namespace
    );

    return 0;
}

1;
