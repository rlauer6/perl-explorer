package Devel::Explorer::Markdown;

use strict;
use warnings;

use Devel::Explorer::Utils qw(:all);
use Digest::MD5 qw(md5_hex);
use English qw(-no_match_vars);
use File::Find;
use List::Util qw(any);
use Markdown::Render;
use File::Basename qw(fileparse);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw(
      config
      css
      engine
      file
      template
    )
);

use Readonly;

Readonly::Scalar our $MARKDOWN_EXT   => 'md';
Readonly::Scalar our $DEFAULT_ENGINE => 'text_markdown';
Readonly::Scalar our $DEFAULT_CSS =>
  'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.5.1/github-markdown.min.css';

use parent qw(Devel::Explorer::Base);

########################################################################
sub set_defaults {
########################################################################
    my ($self) = @_;

    my $config = $self->get_config;

    $self->set_css( $self->get_css // $DEFAULT_CSS );

    $self->set_engine( $self->get_engine // $config->{markdown}->{engine} || 'github' );

    $self->verify_template('markdown');

    return $self;
}

########################################################################
sub render_markdown {
########################################################################
    my ( $self, $file ) = @_;

    $file //= $self->get_file;

    my $html = eval {
        my $md = Markdown::Render->new(
            infile => $file,
            body   => $FALSE,
            engine => $self->get_engine,
            $self->get_engine eq 'github' ? ( mode => 'gfm' ) : (),
        );

        $md->render_markdown;

        return $md->get_html;
    };

    die "error rendering markdown: $EVAL_ERROR\n"
      if !$html || $EVAL_ERROR;

    my ($name) = fileparse( $file, qr/[.][^.]+$/xsm );

    my $config = $self->get_config;

    my $css_path = $config->{site}->{css};

    my $js_path = $config->{site}->{js};

    my $params = {
        body  => $html,
        title => $name,
        css   => fix_path( $css_path, @{ $config->{markdown}->{css} } ),
        js    => fix_path( $js_path,  @{ $config->{markdown}->{js} } ),
    };

    return $self->render( template_name => 'markdown', params => $params );
}

1;
