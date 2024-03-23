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

    $self->set_engine( $self->get_engine // $config->{markdown}->{engine} || 'github' );

    $self->set_markdown_files( [] );

    $self->find_markdown( ignore_paths => ['.git'] );

    $self->verify_template('markdown');

    return $self;
}

########################################################################
sub render_markdown {
########################################################################
    my ( $self, $markdown_id ) = @_;

    my $markdown_file = $self->get_markdown_files->{$markdown_id};
    my $config        = $self->get_config;

    my $fake_path = $config->{docker}->{markdown_path};
    my $real_path = $config->{markdown}->{path};

    $markdown_file =~ s/^$real_path/$fake_path/xsm;

    die "no such id ($markdown_id)\n"
      if !$markdown_file;

    die "$markdown_file not found\n"
      if !-e $markdown_file;

    my $html = eval {
        my $md = Markdown::Render->new(
            infile => $markdown_file,
            body   => $FALSE,
            engine => $self->get_engine,
            $self->get_enginge eq 'github' ? ( mode => 'gfm' ) : (),
        );

        $md->render_markdown;

        return $md->get_html;
    };

    die "error rendering markdown: $EVAL_ERROR\n"
      if !$html || $EVAL_ERROR;

    my ($name) = fileparse( $markdown_file, qr/[.][^.]+$/xsm );

    my $css_path = $config->{site}->{css};

    my $js_path = $config->{site}->{js};

    my $params = {
        body           => $html,
        title          => $name,
        css            => fix_path( $css_path, @{ $config->{markdown}->{css} } ),
        js             => fix_path( $js_path,  @{ $config->{markdown}->{js} } ),
        markdown_files => $self->get_markdown_files,
    };

    return $self->render( template_name => 'markdown', params => $params );
}

########################################################################
sub find_markdown {
########################################################################
    my ( $self, @args ) = @_;

    my $options = get_args(@args);

    my ( $path, $ext, $ignore_paths ) = @{$options}{qw(path ext ignore_paths)};

    $ext //= $MARKDOWN_EXT;

    $path //= $self->get_markdown;
    $self->set_markdown($path);

    return
      if !$path || !-d $path;

    my @files;

    my $real_path = $self->get_config->{markdown}->{path};

    find(
        {   preprocess => sub {
                return ()
                  if any { "$path/$_" eq $File::Find::dir } @{ $ignore_paths || [] };

                return @_;
            },
            wanted => sub {
                return if !/[.]$ext$/xsm;

                my $name = $File::Find::name;
                $name =~ s/$path\///xsm;

                push @files, "$real_path/$name";
            },
            no_chdir => $TRUE,
        },
        $path
    );

    my %markdown_files = reverse map { $_ => md5_hex($_) } @files;

    $self->set_markdown_files( \%markdown_files );

    return \%markdown_files;
}

1;
