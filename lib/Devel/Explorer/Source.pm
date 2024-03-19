package Devel::Explorer::Source;

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
use Devel::Explorer::Search;
use Devel::Explorer;
use List::Util qw(any);

use English qw(-no_match_vars);
use Syntax::SourceHighlight;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
    qw(
      anchored
      css
      css_path
      js
      js_path
      file
      highlighter
      inputlang
      line_numbers
      module
      outputlang
      use_template
      template
      source
    )
);

use parent qw(Devel::Explorer::Base);

caller or __PACKAGE__->main();

########################################################################
sub set_defaults {
########################################################################
    my ($self) = @_;

    my $config = $self->get_config || {};

    my $css      = $self->get_css      // $config->{source}->{css};
    my $css_path = $self->get_css_path // $config->{site}->{css};

    my $js      = $self->get_js      // $config->{source}->{js};
    my $js_path = $self->get_js_path // $config->{site}->{js};

    $css //= ['perl-explorer-source.css'];

    $self->set_css( fix_path( $css_path, $css ) );
    $self->set_js( fix_path( $js_path, $js ) );

    $self->set_outputlang( $self->get_outputlang // 'htmlcss.outlang' );
    $self->set_inputlang( $self->get_inputlang   // 'perl.lang' );

    $self->set_line_numbers( $self->get_line_numbers // $TRUE );

    my $highlighter = Syntax::SourceHighlight->new( $self->get_outputlang );

    $highlighter->setGenerateLineNumbers( $self->get_line_numbers );
    $highlighter->setLineNumberAnchorPrefix('pe-');
    $highlighter->setGenerateLineNumberRefs($TRUE);

    $self->set_highlighter($highlighter);

    $self->verify_template('source');

    return;
}

########################################################################
sub highlight_source_lines {
########################################################################
    my ( $self, @args ) = @_;

    my $options = ref $args[0] ? $args[0] : {@args};

    my ( $file, $source, $module ) = @{$options}{qw(file source)};

    my @source = $self->fetch_source;

    my $highlighter = $self->get_highlighter;

    $highlighter->setGenerateLineNumbers($FALSE);

    my $line_number = 0;

    foreach my $line (@source) {
        $line = $highlighter->highlightString( $line, $self->get_inputlang );
        $line =~ s/<\![^>]+-->\n<pre>//xsm;
        chomp $line;

        $line = sprintf '<pre class="pe-critic-context">[%05d] %s', ++$line_number, $line;
    }

    return \@source;
}

########################################################################
sub fetch_source {
########################################################################
    my ( $self, @args ) = @_;

    my $options = ref $args[0] ? $args[0] : {@args};

    my ( $source, $file ) = @{$options}{qw(source file)};

    $source = eval {
        return $source
          if $source;

        return $self->get_source
          if $self->get_source;

        $file //= $self->get_file;

        $source = slurp_file $file;
    };

    return wantarray ? split /\n/xsm, $source : $source;
}

########################################################################
sub highlight {
########################################################################
    my ( $self, @args ) = @_;

    my $options = ref $args[0] ? $args[0] : {@args};

    my ( $use_template, $module, $dependencies ) = @{$options}{qw(use_template module dependencies)};

    my $highlighter = $self->get_highlighter;
    $use_template //= $self->get_use_template;

    my $source = $self->fetch_source($options);

    die 'no source'
      if $EVAL_ERROR || !$source;

    my $highlighted_source = $highlighter->highlightString( $source, $self->get_inputlang );
    $highlighted_source =~ s/\A<pre/<pre class="pe-source-container">/xsm;

    # TODO: fix regexp
    if ( $options->{add_links} ) {
        while ($highlighted_source =~ /(keyword\">use<\/span>)([^;]+?)(<span\s*class=\"symbol\">);/xsm
            && $highlighted_source !~ /module/ ) {
            $highlighted_source
              =~ s/(keyword\">use<\/span>)([^;]+?)(<span\s*class=\"symbol\">);/$1<span class=\"module\">$2<\/span>$3;<\/span>/xsmg;
        }
    }

    my $template = slurp_file( $self->get_template );

    return $highlighted_source
      if !$use_template || !$template;

    my $params = {
        dependencies => $dependencies,
        lines        => scalar( split /\n/xsm, $source ),
        source       => $highlighted_source,
        css          => $self->get_css,
        js           => $self->get_js,
        todos        => $options->{todos},
        subs         => find_subs($source),
        linenum      => $options->{linenum} // 1,
        module       => $module // $options->{file} // $self->get_file // $EMPTY,
    };

    my $output = tt_process( $template, $params );

    dbg output => $output;

    return $output;
}

########################################################################
sub find_subs {
########################################################################
    my ($source) = @_;

    my $linenum = 0;

    my @subs_by_linenum;

    foreach my $line ( split /\n/xsm, $source ) {
        ++$linenum;
        next if $line !~ /^\s*sub\s+([^{]+)\s+[{]/xsm;

        push @subs_by_linenum, [ sprintf( '%05d', $linenum ), $1 ];
    }

    @subs_by_linenum = sort { $a->[1] cmp $b->[1] } @subs_by_linenum;

    return \@subs_by_linenum;
}

########################################################################
sub create_reverse_dependency_listing {
########################################################################
    my ( $self, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $module ) = @{$options}{qw(explorer module)};

    my %package_names = reverse %{ $explorer->get_package_names };

    my $search = Devel::Explorer::Search->new();

    my $found = $search->search_all(
        regexp   => qr/[^:]$module[^:]/xsm,
        modules  => $explorer->get_modules,
        callback => sub {
            my ( $file, $results ) = @_;

            my $package_name = $package_names{$file};

            $results->{$file} = [ $results->{$file}, $package_name ];

            return;
        }
    );

    my $results = {};

    foreach my $file ( keys %{$found} ) {
        my ( $lines, $found_module ) = @{ $found->{$file} };
        $results->{$found_module} = [ $lines, $file ];
    }

    delete $results->{$module};  # module does not depend on module

    return $results;
}

########################################################################
sub create_dependency_listing {
########################################################################
    my ( $self, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $file, $source, $module ) = @{$options}{qw( explorer file source module)};

    my %package_names = %{ $explorer->get_package_names };

    if ( !$source ) {
        $file //= $package_names{$module};

        die "no source\n"
          if !$file || !-e $file;

        $source = slurp_file $file;
    }

    my $dependencies = find_requires($source);

    my $has_pod  = {};
    my $is_local = {};

    my @package_names = keys %{ $explorer->get_package_names };

    foreach my $m ( @{$dependencies} ) {
        $has_pod->{$m}  = $explorer->has_pod($m);
        $is_local->{$m} = ( any { $m eq $_ } @package_names ) ? $TRUE : $FALSE;
    }

    my $reverse_dependency_listing = $self->create_reverse_dependency_listing(
        module   => $module,
        explorer => $explorer
    );

    return {
        reverse_dependencies => $reverse_dependency_listing,
        modules              => $dependencies,
        has_pod              => $has_pod,
        is_local             => $is_local,
    };
}

########################################################################
sub main {
########################################################################

    my $explorer = Devel::Explorer->new( config => { path => $ARGV[0] } );

    # my $source_explorer = Devel::Explorer::Source->new( file => $ARGV[0], use_template => 1 );

    my $source_explorer = Devel::Explorer::Source->new( skip_defaults => $TRUE );

    dbg dependencies => $source_explorer->create_dependency_listing(
        explorer => $explorer,
        module   => $ARGV[1],
    );

    #    dbg reverse_dependencies => $source_explorer->reverse_dependency_listing(
    #        explorer => $explorer,
    #        module   => $ARGV[1]
    #    );

    return 0;
}

1;
