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
use English                qw(-no_match_vars);
use File::Find;
use HTML::Tidy;
use JSON;
use List::Util qw(pairs);
use Template;

use parent qw(Class::Accessor::Fast);

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw(
      branches
      config
      config_file
      modules
      package_names
      path
      pod_status
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

    my @modules;

    my $config = $self->init_config;

    my $path = $self->get_path // $config->{path};

    if ($path) {
        croak "invalid path to Perl modules ($path)\n"
          if !-d $path;

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

        $self->set_modules( \%paths );

        $self->create_tree();
        $self->update_pod_status();
    }

    return $self;
}

########################################################################
sub get_module_path {
########################################################################
    my ( $self, $module ) = @_;

    my %modules = reverse %{ $self->get_modules // {} };

    my $file = $modules{$module};

    return $file && -e $file ? $file : $EMPTY;
}

########################################################################
sub has_pod {
########################################################################
    my ( $self, $module ) = @_;

    return $self->get_pod_status->{$module};
}

########################################################################
sub update_pod_status {
########################################################################
    my ($self) = @_;

    my $modules = $self->get_modules;
    my @paths   = keys %{ $self->get_modules };

    my %pod_status;
    my %package_names;

    foreach my $file (@paths) {
        my $text = eval { return slurp_file($file); };
        my $package_name;

        if ( $text =~ /^package\s+([^;]+);/xsm ) {
            $package_name = $1;

            $package_names{$package_name} = $file;
        }

        if ( $text && $text =~ /^[=]pod\s*$/xsm ) {
            $pod_status{ $modules->{$file} } = length $text;
        }
        else {
            $pod_status{ $modules->{$file} } = 0;
        }

        $pod_status{$package_name} = $pod_status{ $modules->{$file} };
    }

    $self->set_package_names( \%package_names );

    return $self->set_pod_status( \%pod_status );
}

########################################################################
sub init_config {
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
sub expand_branch {
########################################################################
    my ( $self, $branch ) = @_;

    my $tree = $self->get_tree;

    my $branches = $self->get_branches;

    my @parts = split /$DOUBLE_COLON/xsm, $branch;

    my @leaves = @{ $branches->{$branch} };

    foreach (@parts) {
        $tree = $tree->{$_};
    }

    $branches = [ map { $branch . $DOUBLE_COLON . $_ } keys %{$tree} ];

    return { leaves => \@leaves, branches => $branches };
}

########################################################################
sub traverse_tree {
########################################################################
    my ( $self, $branch, $tree, $leaves ) = @_;

    $leaves //= [];

    foreach my $twig ( keys %{$branch} ) {
        my $next_branch = join $DOUBLE_COLON, @{$tree}, $twig;
        push @{$leaves}, $next_branch;

        next if !ref $branch->{$twig};

        $self->traverse_tree( $branch->{$twig}, [ @{$tree}, $twig ], $leaves );
    }

    return @{$leaves};
}

########################################################################
sub create_tree {
########################################################################
    my ($self) = @_;

    my @modules = values %{ $self->get_modules };

    my $tree = {};

    foreach my $module (@modules) {

        my @parts = split /$DOUBLE_COLON/xsm, $module;
        pop @parts;

        my $leaf = $tree;

        foreach my $p (@parts) {
            $leaf->{$p} //= {};
            $leaf = $leaf->{$p};
        }

    }

    my %leaves = map { $_ => [] } $self->traverse_tree( $tree, [] );

    foreach my $module (@modules) {
        my @parts = split /$DOUBLE_COLON/xsm, $module;
        pop @parts;

        my $leaf = join $DOUBLE_COLON, @parts;

        push @{ $leaves{$leaf} }, $module;
    }

    $self->set_tree($tree);

    $self->set_branches( \%leaves );

    return ( $tree, \%leaves );
}

########################################################################
sub show_branch {
########################################################################
    my ( $branches, $branch_name, $parents, $options ) = @_;

    my $level = $parents ? scalar @{$parents} : 1;

    $parents //= [];

    my $this_branch = join $DOUBLE_COLON, @{$parents}, $branch_name;

    my $id = $options->{class};

    my $class = 'branch_' . $id;

    #         <span style="display:inline-block; text-align:center;">
    #         <img class="folder" src="/icons/folder.png" style="display:inline-block; padding-right:10px;">
    #         <img class="folder" src="/icons/folder.open.png" style="display:none; padding-right:10px;">
    #         %s
    #       </span>

    my $folders = <<"END_OF_HTML";
     <h3 class="dir" id="%s">
      <i class="folder fa fa-folder-open" style="display: none;"></i>
      <i class="folder fa fa-folder"></i>
      %s
     </h3>
END_OF_HTML

    my $h3 = sprintf $folders, $id, $this_branch;

    $options->{html} .= $h3;

    my @modules    = @{ $branches->{$this_branch} || [] };
    my %pod_status = %{ $options->{pod_status} };

    if (@modules) {

        my @li;

        foreach ( sort @modules ) {
            my $class = sprintf 'class="module%s"', $pod_status{$_} ? ' pod' : '';
            push @li, sprintf '<li %s>%s</li>', $class, $_;
        }

        $options->{html} .= sprintf qq{\n<div class="branch $class">\n<ul>\n%s\n</ul>\n</div>\n}, join "\n", @li;
    }

    return { $this_branch => [@modules] };
}

########################################################################
sub walk_tree {
########################################################################
    my ( $tree, $node, $parents, $callback, $options ) = @_;

    # $options->{html} .= qq{\n<div class="branch">\n};

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
    my ( $self, $root ) = @_;

    my $options = {
        branches   => $self->get_branches,
        html       => $EMPTY,
        pod_status => $self->get_pod_status
    };

    walk_tree(
        $self->get_tree,
        $root,
        [],
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

    my $body = $self->directory_index_body($root);

    my $markdown = Devel::Explorer::Markdown->new( config => $config );

    my $params = {
        markdown_files => $markdown->get_markdown_files,
        site           => $config->{site},
        module_listing => $body,
        logo           => $config->{site}->{logo} ? $config->{site}->{logo} : $EMPTY,
        js             => fix_path( $config->{site}->{js},  $config->{index}->{js} ),
        css            => fix_path( $config->{site}->{css}, $config->{index}->{css} ),
    };

    my $output = tt_process( $template, $params );

    return $output;

    return HTML::Tidy->new(
        {   'indent-spaces' => 2,
            wrap            => 120,
            indent          => 1,
            'output-html'   => 0,
        }
    )->clean($output);
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
