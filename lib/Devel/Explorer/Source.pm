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
use English                qw(-no_match_vars);
use Syntax::SourceHighlight;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
    qw(
      css
      css_path
      js
      js_path
      file
      highlighter
      inputlang
      line_numbers
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
        module       => $module // $options->{file} // $self->get_file // $EMPTY,
    };

    my $output = tt_process( $template, $params );

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
sub main {
########################################################################

    my $file = shift @ARGV;

    my $explorer = Devel::Explorer::Source->new( file => $file, use_template => 1 );

    return 0;
}

1;
