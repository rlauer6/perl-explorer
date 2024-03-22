package Devel::Explorer::Markdown;

use strict;
use warnings;

use Devel::Explorer::Utils qw(:all);
use English qw(-no_match_vars);
use File::Find;

use Markdown::Render;
use Digest::MD5 qw(md5_hex);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    config
    css
    engine
    markdown
    markdown_files
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

  my $markdown = $self->get_markdown // $config->{docker}->{markdown_path};
  $self->set_markdown($markdown);
  $self->set_css( $self->get_css // $DEFAULT_CSS );

  $self->set_engine( $self->get_engine // $config->{markdown}->{engine} // 'text_markdown' );

  $self->set_markdown_files( [] );

  $self->find_markdown();

  $self->verify_template('markdown');

  return $self;
}

########################################################################
sub render_markdown {
########################################################################
  my ( $self, $markdown_id ) = @_;

  my $markdown_file = $self->get_markdown_files->{$markdown_id};

  die "no such id ($markdown_id)\n"
    if !$markdown_file;

  die "$markdown_file not found\n"
    if !-e $markdown_file;

  my $html = eval {
    my $md = Markdown::Render->new(
      infile => $markdown_file,
      body   => $FALSE,
      engine => $self->get_engine,
    );

    $md->render_markdown;

    return $md->get_html;
  };

  die "error rendering markdown: $EVAL_ERROR\n"
    if !$html || $EVAL_ERROR;

  return $self->render( template_name => 'markdown', params => { body => $html } );
}

########################################################################
sub find_markdown {
########################################################################
  my ( $self, $path, $ext ) = @_;

  $ext //= $MARKDOWN_EXT;

  $path //= $self->get_markdown;
  $self->set_markdown($path);

  return
    if !$path || !-d $path;

  my @files;

  find(
    sub {
      return if !/[.]$ext$/xsm;
      push @files, $File::Find::name;
    },
    $path
  );

  my %markdown_files = reverse map { $_ => md5_hex($_) } @files;

  $self->set_markdown_files( \%markdown_files );

  return \%markdown_files;
}

1;
