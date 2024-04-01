package Devel::Explorer;

use strict;
use warnings;

BEGIN {
  my $home = $ENV{HOME};

  if ($home) {
    my @lib = ( 'lib', sprintf '%s/lib/perl5', $home );

    use lib @lib;
  }
}

use Carp;
use Cwd;
use Data::Dumper;
use Devel::Explorer::Markdown;
use Devel::Explorer::Utils qw(:all);
use Digest::MD5 qw(md5_hex);
use English qw(-no_match_vars);
use File::Find;
use File::Basename qw(fileparse);
use HTML::Tidy5;
use JSON;
use List::Util qw(pairs any sum none);
use Template;
use Text::Gitignore qw(match_gitignore);
use Scalar::Util qw(reftype);
use Stat::lsMode;

use parent qw(Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
  qw(
    branches
    config
    config_file
    file_info
    file_map
    ignore_list
    allow_list
    markdown
    modules
    package_names
    path
    repo
    tree
  )
);

caller or __PACKAGE__->main();

########################################################################
sub new {
########################################################################
  my ( $class, @args ) = @_;

  my $options = ref $args[0] ? $args[0] : {@args};

  my $self = $class->SUPER::new($options);

  $self->init();

  return $self;
}

########################################################################
sub init {
########################################################################
  my ($self) = @_;

  my @modules;

  my $config = $self->fetch_config;

  my $repo = $self->get_repo;

  $self->set_file_info( {} );
  $self->set_modules( {} );

  return
    if !$repo;

  my $repo_list = $config->{repo};

  my $path = $self->get_path // sprintf '/perl-explorer/%s', $repo;

  die "invalid path ($path)\n"
    if !-d $path;

  # setup allow, ignore lists
  for my $list (qw(ignore allow)) {
    my @list = fetch_ignore_list( $path, $config->{$list} );

    if ( $config->{repo}->{$repo}->{$list} ) {
      push @list, fetch_ignore_list( $path, $config->{repo}->{$repo}->{$list} );
    }

    my $method = "set_${list}_list";
    $self->$method( \@list );
  }

  my $file_info = $self->fetch_file_list( path => $path );

  $self->set_file_info($file_info);

  # create a map of Perl modules => file ids
  my %modules;
  my %file_map;

  foreach my $id ( keys %{$file_info} ) {
    my $file = $file_info->{$id};

    # lookup id by filename
    $file_map{ $file->{vpath} } = $id;

    if ( $file->{package_name} ) {
      foreach ( @{ $file->{package_name} } ) {
        $modules{$_} = $id;
      }
    }
  }

  $self->set_modules( \%modules );
  $self->set_file_map( \%file_map );

  my ( $tree, $branches ) = $self->create_tree();

  $self->set_tree($tree);
  $self->set_branches($branches);

  return $self;
}

########################################################################
sub get_file_by_id {
########################################################################
  my ( $self, $id ) = @_;

  my $file_info = $self->get_file_info;

  return
    if !$file_info || !ref $file_info;

  my $id_list = ref $id ? $id : [$id];

  my @file_list = map { $file_info->{$_}->{vpath} } @{$id_list};

  @file_list = grep { -e $_ } @file_list;

  return wantarray ? @file_list : $file_list[0];
}

########################################################################
sub get_file_by_module {
########################################################################
  my ( $self, $module ) = @_;

  return $self->get_file_by_id( $self->get_modules->{$module} );
}

########################################################################
sub has_pod {
########################################################################
  my ( $self, $id ) = @_;

  if ( $id !~ /^[[:digit:]a-f]{32}$/xsm ) {
    $id = $self->get_modules->{$id};
  }

  return
    if !$id;

  return $self->get_file_info->{$id}->{has_pod};
}

########################################################################
sub fetch_config {
########################################################################
  my ($self) = @_;

  my $config      = $self->get_config // {};
  my $config_file = $self->get_config_file;

  if ( $config_file && -e $config_file ) {
    $config = slurp_json($config_file);
  }

  $self->set_config($config);

  $self->resolve_dir(qw(path critic.profile templates.index tidy.profile));

  return $config;
}

########################################################################
sub _get_value_from_dotted_path {
########################################################################
  my ( $config, $dotted_path ) = @_;

  my @parts;

  my @path = split /[.]/xsm, $dotted_path;
  my $var  = pop @path;

  foreach (@path) {
    $config = $config->{$_};
  }

  return ( $config, $var );
}

########################################################################
sub resolve_dir {
########################################################################
  my ( $self, @paths ) = @_;

  my $config = $self->get_config;

  my $home = $config->{home};

  return
    if !$home;

  foreach my $p (@paths) {
    my ( $config_path, $var ) = _get_value_from_dotted_path( $config, $p );

    my $val = $config_path->{$var};
    $val =~ s/~/$home/xsm;

    $config_path->{$var} = $val;
  }

  return $self;
}

########################################################################
sub traverse_tree {
########################################################################
  my ( $branch, $tree, $leaves ) = @_;

  $leaves //= [];

  foreach my $twig ( keys %{$branch} ) {
    my $next_branch = join q{/}, @{$tree}, $twig;
    push @{$leaves}, $next_branch;

    next if !ref $branch->{$twig};

    traverse_tree( $branch->{$twig}, [ @{$tree}, $twig ], $leaves );
  }

  return @{$leaves};
}

########################################################################
sub create_tree {
########################################################################
  my ($self) = @_;

  my $file_info = $self->get_file_info;

  my @files = map { $file_info->{$_}->{vpath} } keys %{$file_info};

  my $tree = {};

  foreach my $file (@files) {

    my @parts = split /\//xsm, $file;
    pop @parts;

    my $leaf = $tree;

    foreach my $p (@parts) {
      next if !$p;
      $leaf->{$p} //= {};
      $leaf = $leaf->{$p};
    }
  }

  my %leaves = map { $_ => [] } traverse_tree( $tree, [] );

  foreach my $file (@files) {
    my @parts = split /\//xsm, $file;
    pop @parts;

    my $leaf = join q{/}, @parts;

    push @{ $leaves{$leaf} }, $file;
  }

  return ( $tree, \%leaves );
}

########################################################################
sub show_branch {
########################################################################
  my ( $branches, $branch_name, $parents, $options ) = @_;

  my $level = $parents ? scalar @{$parents} : 1;

  $parents //= [];

  my $this_branch = q{/} . join q{/}, @{$parents}, $branch_name;

  my $id = $options->{class};

  my $folders = <<"END_OF_HTML";
     <h3 class="dir" id="%s">
      <i class="folder fa fa-folder-open" style="display: none;"></i>
      <i class="folder fa fa-folder"></i>
      %s
     </h3>
END_OF_HTML

  my $root = $options->{root};

  my $display_branch = $this_branch;

  $display_branch =~ s/$root\/?//xsm;

  my $h3 = sprintf $folders, $id, $display_branch;

  $options->{html} .= $h3;

  my @files = @{ $branches->{$this_branch} || [] };

  my $file_map  = $options->{explorer}->get_file_map;
  my $file_info = $options->{explorer}->get_file_info;

  if (@files) {

    my @li;

    foreach ( sort @files ) {
      my $id = $file_map->{$_};

      my $display_name = $_;
      $display_name =~ s/$root\/?//xsm;

      my @classes = 'pe-source-file';

      if ( $display_name =~ /[.]pm$/xsm ) {
        push @classes, 'pe-module';
      }

      if ( $file_info->{$id}->{has_pod} ) {
        push @classes, 'pe-pod';
      }

      dbg file_info => $file_info->{$id};

      my $class = sprintf 'class="%s"', join q{ }, @classes;

      push @li,
        sprintf
        '<li id="%s" %s><span class="pe-display-name">%s</span><span class="pe-vertical-elipsis">&#x22EE;</span></li>',
        $id, $class, $display_name;
    }

    $options->{html} .= sprintf qq{\n<div class="branch branch_$id">\n<ul>\n%s\n</ul>\n</div>\n}, join "\n", @li;
  }

  return { $this_branch => [@files] };
}

########################################################################
sub walk_tree {
########################################################################
  my ( $tree, $node, $parents, $callback, $options ) = @_;

  my $class = $options->{class} // 0;
  $class++;

  $options->{class} = $class;
  $options->{id}    = $node;

  if ($callback) {
    $callback->( $tree, $node, $parents, $options );
  }

  if ($node) {
    push @{$parents}, $node;
  }

  my @branch_parents = @{$parents};

  foreach my $branch ( sort keys %{ $tree->{$node} } ) {

    if ( !$tree->{$node}->{$branch} ) {
      $parents = [@branch_parents];
      next;
    }
    $options->{html} .= qq{\n<div class="branch branch_$class" >\n};
    walk_tree( $tree->{$node}, $branch, $parents, $callback, $options );
    $options->{html} .= qq{\n</div>};

    $parents = [@branch_parents];
  }

  return;
}

########################################################################
sub directory_index_body {
########################################################################
  my ( $self, $root, $tree, $branches ) = @_;

  my $options = {
    branches => $branches,
    html     => q{},
    root     => $root,
    explorer => $self,
  };

  my (@path) = split /\//xsm, $root;

  my $node = pop @path;

  my @parents = grep {/./xsm} @path;

  while (@path) {
    $tree = $tree->{ shift @path };
  }

  walk_tree(
    $tree, $node,
    [@parents],
    sub {
      my ( $tree, $branch, $parents, $options ) = @_;

      show_branch( $options->{branches}, $branch, $parents, $options );
    },
    $options,
  );

  my $html = $options->{html};  # . '</div>';

  while ( $html =~ s/<div class="branch">\n<\/div>\n//xsmg ) { }

  return $html;
}

########################################################################
sub fetch_template {
########################################################################
  my ($self) = @_;

  my $config = $self->get_config;

  my $template_path = $config->{templates}->{index};

  die "no template specified in config\n"
    if !$template_path;

  die "template_path not valid [$template_path]n"
    if !-e $template_path;

  return slurp_file($template_path);
}

########################################################################
sub directory_index {
########################################################################
  my ( $self, $root ) = @_;

  die "usage: directory_index(root)\n"
    if !defined $root;

  my $config = $self->get_config;

  my $template = $self->fetch_template;

  die "no index template found!\n"
    if !$template;

  my $body = $self->directory_index_body( $root, $self->get_tree, $self->get_branches );

  my $file_info = $self->get_file_info;

  my @markdown = grep { $file_info->{$_}->{ext} && $file_info->{$_}->{ext} eq '.md' } keys %{$file_info};

  my %markdown_files = reverse map { $_->{path} => md5_hex( $_->{path} ) } @{$file_info}{@markdown};

  my $markdown = Devel::Explorer::Markdown->new( config => $config, markdown_files => \%markdown_files );

  my $params = {
    repo           => $self->get_repo,
    markdown_files => \%markdown_files,
    site           => $config->{site},
    module_listing => $body,
    logo           => $config->{site}->{logo} ? $config->{site}->{logo} : $EMPTY,
    js             => fix_path( $config->{site}->{js},  $config->{index}->{js} ),
    css            => fix_path( $config->{site}->{css}, $config->{index}->{css} ),
  };

  my $output = tt_process( $template, $params );

  my $tidy = HTML::Tidy5->new(
    { indent_spaces         => 2,
      wrap                  => 120,
      indent                => $TRUE,
      output_xhtml          => $TRUE,
      'drop-empty-elements' => $FALSE,
    }
  );

  my $tidy_html = $tidy->clean($output);

  return $tidy_html;
}

########################################################################
sub fetch_file_list {
########################################################################
  my ( $self, @args ) = @_;

  my $options = get_args(@args);

  my $verbose = $options->{verbose} // 0;

  my $config = $self->get_config;
  my $repo   = $self->get_repo;

  my ( $path, $ignore_list, $allow_list ) = @{$options}{qw(path ignore allow)};

  if ( !$ignore_list ) {
    $ignore_list = $self->get_ignore_list || [];
  }

  if ( !$allow_list ) {
    $allow_list = $self->get_allow_list || [];
  }

  $path //= $EXPLORER_ROOT . '/' . $repo;

  my @file_list;

  find(
    { preprocess => sub {
        my @list = @_;

        my %file_map = map { "$File::Find::dir/" . $_ => $_ } @list;

        my @ignore_these = @{$ignore_list} ? match_gitignore( $ignore_list, keys %file_map ) : ();
        my @allow_these  = @{$allow_list}  ? match_gitignore( $allow_list,  keys %file_map ) : ();

        @ignore_these = map { $file_map{$_} } @ignore_these;
        @allow_these  = map { $file_map{$_} } @allow_these;

        my @ok_files;

        foreach my $f (@list) {
          next if ( any { $f eq $_ } @ignore_these ) && none { $f eq $_ } @allow_these;
          push @ok_files, $f;
        }

        return @ok_files;
      },
      wanted => sub {
        push @file_list, $File::Find::name;
      }
    },
    $path
  );

  my %file_info;

  my $root = $config->{repo}->{$repo}->{root};

  foreach my $file (@file_list) {
    next if -d $file;

    my ( $name, undef, $ext ) = fileparse( $file, qr/[.][^.]+$/xsm );
    my $real_path = $file;
    $real_path =~ s/$path/$root/xsm;

    my $filename = "$name$ext";

    my (@source) = eval { slurp_file $file; };

    warn "could not read $file: $EVAL_ERROR\n"
      if $verbose && !@source || $EVAL_ERROR;

    next
      if !@source || $EVAL_ERROR;

    my $id = md5_hex($real_path);

    my $stat = [ stat $file ];

    $file_info{$id} = {
      path          => $real_path,
      vpath         => $file,
      stat          => $stat,
      last_modified => scalar( localtime $stat->[9] ),
      permissions   => scalar( format_mode( $stat->[2] ) ),
      name          => $filename,
      id            => $id,
      ext           => $ext,
      size          => ( -s $file ),
      lines         => scalar(@source),
      has_pod       => $FALSE,
      todos         => sum map { /[#][#]\sTODO/xsm ? 1 : 0 } @source,
    };

    next
      if $file !~ /[.]p[lm]$/xsm;

    $file_info{$id}->{has_pod} = ( any { $_ =~ /^=pod/xsm } @source ) ? $TRUE : $FALSE;

    for (@source) {
      next
        if !/^package\s([^;]+);\s*$/xsm;

      # could be multiple packages in file
      if ( $file_info{$id}->{package_name} ) {
        my $package_names = $file_info{$id}->{package_name};

        if ( !ref $package_names ) {
          $package_names = [$package_names];
        }

        push @{$package_names}, $1;
      }
      else {
        $file_info{$id}->{package_name} = [$1];
      }
    }
  }

  return \%file_info;
}

########################################################################
sub verify_id {
########################################################################
  my ( $explorer, $id ) = @_;

  if ( $id !~ /^[[:digit:]a-f]{32}$/xsm ) {
    return $explorer->get_modules->{$id};
  }

  return $id;
}

########################################################################
sub main {
########################################################################
  my ( $class, @args ) = @_;

  my $config = {
    path  => getcwd . '/lib',
    index => {
      template_path => 'perl-explorer.html',
      css_path      => '/static/css/perl-explorer.css',
      js_path       => '/static/js/perl-explorer.js',
      jquery_path   => '/static/js/jquery-3.6.0.min.js',
    },
  };

  my $explorer = Devel::Explorer->new( config => $config );

  print $explorer->directory_index('E2E');

  return 0;
}

1;
