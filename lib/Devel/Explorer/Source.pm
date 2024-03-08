#!/usr/bin/perl

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

use parent qw(Exporter Class::Accessor::Fast);

our $DEFAULT_TEMPLATE = q{};

while ( my $line = <DATA> ) {
    last if $line =~ /^=pod/xsm;

    $DEFAULT_TEMPLATE .= $line;
}

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

    $self->set_css( $self->get_css           // ['perl-explorer-source.css'] );
    $self->set_css_path( $self->get_css_path // ['/css'] );

    $self->set_css( fix_path( $self->get_css_path, $self->get_css ) );
    $self->set_js( fix_path( $self->get_js_path, $self->get_js ) );

    $self->set_outputlang( $self->get_outputlang // 'htmlcss.outlang' );
    $self->set_inputlang( $self->get_inputlang   // 'perl.lang' );

    $self->set_line_numbers( $self->get_line_numbers // $TRUE );

    my $highlighter = Syntax::SourceHighlight->new( $self->get_outputlang );

    $highlighter->setGenerateLineNumbers( $self->get_line_numbers );

    $self->set_highlighter($highlighter);

    $self->set_template( $self->get_template // $DEFAULT_TEMPLATE );

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

    my ( $use_template, $module ) = @{$options}{qw(use_template module)};

    my $highlighter = $self->get_highlighter;
    $use_template //= $self->get_use_template;

    my $source = $self->fetch_source($options);

    die 'no source'
      if $EVAL_ERROR || !$source;

    my $highlighted_source = $highlighter->highlightString( $source, $self->get_inputlang );

    # TODO: fix regexp
    if ( $options->{add_links} ) {
        while ($highlighted_source =~ /(keyword\">use<\/span>)([^;]+?)(<span\s*class=\"symbol\">);/xsm
            && $highlighted_source !~ /module/ ) {
            $highlighted_source
              =~ s/(keyword\">use<\/span>)([^;]+?)(<span\s*class=\"symbol\">);/$1<span class=\"module\">$2<\/span>$3;<\/span>/xsmg;
        }
    }

    my $template = $self->get_template;

    return $highlighted_source
      if !$use_template || !$template;

    my $params = {
        source => $highlighted_source,
        css    => $self->get_css,
        js     => $self->get_js,
        module => $module // $options->{file} // $self->get_file // $EMPTY,
    };

    my $output = tt_process( $template, $params );

    return $output;
}

########################################################################
sub main {
########################################################################

    my $file = shift @ARGV;

    my $explorer = Devel::Explorer::Source->new( file => $file, use_template => 1 );

    return 0;
}

1;

__DATA__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    [% FOREACH file IN css -%]
    <link rel="stylesheet" type="text/css" href="[% file %]">
    [% END %]
    [% FOREACH file IN js -%]
    <script src="[% file %]" type="text/javascript"></script>
    [% END %]
    <title>[% module %]</title>
  </head>
  
  <body>
  [% source %]
  </body>
</html>

=pod

=cut
