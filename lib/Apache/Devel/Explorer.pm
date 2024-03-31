package Apache::Devel::Explorer;

use strict;
use warnings;

BEGIN {
    if ( $ENV{MOD_PERL} ) {
        require Apache2::compat;
    }
}

use Apache2::Log;
use Apache2::Request;
use Carp;
use Carp::Always;
use Data::Dumper;
use Devel::Explorer::Utils qw(:all);
use Devel::Explorer;
use Devel::Explorer::Critic;
use Devel::Explorer::Markdown;
use Devel::Explorer::PodWriter qw(pod2html);
use Devel::Explorer::Search;
use Devel::Explorer::Source;
use Devel::Explorer::Tidy;
use Devel::Explorer::ToDo;
use English qw(-no_match_vars);
use File::Basename;
use File::Find;
use File::Temp;
use JSON;
use List::Util qw(any);

use Apache2::Const -compile => qw(
  HTTP_OK
  HTTP_UNSUPPORTED_MEDIA_TYPE
  HTTP_UNAUTHORIZED
  HTTP_BAD_REQUEST
  NOT_FOUND
  OK
  SERVER_ERROR
  FORBIDDEN
  DECLINED
  REDIRECT
  :log
);

use Readonly;

Readonly::Scalar our $ROOT_NODE   => q{};
Readonly::Scalar our $BUFFER_SIZE => 4096;

Readonly::Hash our %APACHE_LOG_LEVELS => (
    DEBUG => Apache2::Const::LOG_DEBUG,
    INFO  => Apache2::Const::LOG_INFO,
    ERROR => Apache2::Const::LOG_ERR,
    WARN  => Apache2::Const::LOG_WARNING,
);

Readonly our $HTTP_UNSUPPORTED_MEDIA_TYPE => Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;
Readonly our $HTTP_UNAUTHORIZED           => Apache2::Const::HTTP_UNAUTHORIZED;
Readonly our $NOT_FOUND                   => Apache2::Const::NOT_FOUND;
Readonly our $OK                          => Apache2::Const::OK;
Readonly our $HTTP_OK                     => Apache2::Const::HTTP_OK;
Readonly our $SERVER_ERROR                => Apache2::Const::SERVER_ERROR;
Readonly our $HTTP_BAD_REQUEST            => Apache2::Const::HTTP_BAD_REQUEST;
Readonly our $FORBIDDEN                   => Apache2::Const::FORBIDDEN;
Readonly our $DECLINED                    => Apache2::Const::DECLINED;
Readonly our $REDIRECT                    => Apache2::Const::REDIRECT;

Readonly our $UNSUPPORTED => Apache2::Const::HTTP_UNSUPPORTED_MEDIA_TYPE;

########################################################################
sub find_module {
########################################################################
    my ( $r, $module_name, @extra_paths ) = @_;

    $module_name =~ s/::/\//gxsm;
    $module_name = "$module_name.pm";

    my $module = eval {
        foreach my $path ( @extra_paths, @INC ) {
            dbg
              path   => $path,
              module => $module_name;

            return "$path/$module_name"
              if -e "$path/$module_name";
        }
    };

    return $module;
}
########################################################################
sub parse_uri {
########################################################################
    my ($uri) = @_;

    my $uri_path = $EMPTY;
    my $repo     = $EMPTY;

    if ( $uri =~ /\/explorer\/pod\/(.*)?/xsm ) {
        $uri_path = $uri;
    }
    elsif ( $uri =~ /\/explorer\/([^\/]+)\/?(.*)$/xsm ) {
        $repo     = $1;
        $uri_path = $2;
    }

    return ( $uri_path, $repo );
}

# +------------------------------+
# | mod_perl HANDLER STARTS HERE |
# +------------------------------+

########################################################################
sub handler {
########################################################################
    my ($r) = @_;

    my $uri = $r->uri;

    my ( $uri_path, $repo ) = parse_uri($uri);

    dbg
      uri_path => $uri_path,
      repo     => $repo;

    my $explorer = eval { return init_explorer( $r, repo => $repo ); };

    my $err = $EVAL_ERROR;

    if ( !$explorer || $err ) {
        return html_error(
            $r,
            msg     => 'could not initialize Perl explorer',
            context => { error => $err }
        );
    }

    if ( !$uri_path ) {
        return explorer( $r, explorer => $explorer );
    }

    if ( $uri_path =~ /markdown\/([[:digit:]a-f]{32})$/xsm ) {
        return show_markdown( $r, explorer => $explorer, markdown_id => $1 );
    }

    if ( $uri_path =~ /^source\//xsm ) {
        my @uri_parts = split /\//xsm, $uri_path;

        my $dispatch = {
            search => \&api_search,
            pod    => \&show_pod,
            todos  => \&api_todos,
        };
    }

    if ( $uri_path =~ /source\/search/xsm ) {
        return api_search( $r, explorer => $explorer );
    }

    if ( $uri_path =~ /pod\/(.+)$/xsm ) {
        return show_pod( $r, module => $1, explorer => $explorer );
    }

    if ( $uri_path =~ /source\/todos\/?/xsm ) {
        my $critic = $FALSE;

        if ( $uri_path =~ /todos\/critic/xsm ) {
            $critic = $TRUE;
        }

        return api_todos( $r, explorer => $explorer, critic => $critic );
    }

    if ( $uri_path =~ /source\/(.+)$/xsm ) {
        my $id = $1;

        if ( $id !~ /^[[:digit:]a-f]{32}$/xsm ) {
            $id = $explorer->get_modules->{$id};

            return $NOT_FOUND
              if !$id;
        }

        return show_source( $r, id => $id, explorer => $explorer );
    }

    if ( $uri_path =~ /^source-lines\/(.+)$/xsm ) {
        return api_source_lines( $r, module => $1, explorer => $explorer );
    }

    if ( $uri_path =~ /^critic\/(.+)$/xsm ) {
        return show_critique( $r, module => $1, explorer => $explorer );
    }

    return html_error(
        $r,
        msg      => 'NOT FOUND',
        status   => $NOT_FOUND,
        explorer => $explorer
    );
}

########################################################################
sub show_markdown {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $markdown_id ) = @{$options}{qw(explorer markdown_id)};

    my $file = $explorer->get_file_by_id($markdown_id);

    dbg
      file => $file,
      id   => $markdown_id;

    my $md = Devel::Explorer::Markdown->new( file => $file, config => $explorer->get_config );

    my $html = $md->render_markdown();

    output_html( $r, $html );

    return $OK;
}

########################################################################
sub around_lines {
########################################################################
    my ( $source, $lines, $line_number ) = @_;

    return $source
      if !$lines;

    my @range = map { $line_number + ( -$lines + $_ ) } ( 0 .. 2 * $lines );

    @range = grep { $_ >= 0 && $_ < @{$source} } @range;

    return [ @{$source}[@range] ];
}

########################################################################
sub fetch_json_payload {
########################################################################
    my ($r) = @_;

    my $content_type = $r->headers_in->get('Content-type');

    die "not a JSON payload\n"
      if $content_type !~ /json/xsm;

    my $method = $r->method;

    my $content_length = $r->headers_in->get('Content-Length');

    my $body;

    my $buffer;

    while ( $r->read( $buffer, $BUFFER_SIZE ) ) {
        $body .= $buffer;
    }

    die sprintf "expected %s, got %s\n", $content_length, length $body
      if $content_length != length $body;

    return JSON->new->decode($body);
}

# critic means that we are adding TODOs based on a Perl::Critic finding
########################################################################
sub api_todos {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $module, $no_critic ) = @{$options}{qw(explorer module critic)};

    my $todo_list = eval { return fetch_json_payload($r); };

    if ( !$todo_list || $EVAL_ERROR ) {
        output_json(
            $r,
            {   error => $EVAL_ERROR,
                uri   => $r->uri,
            },
            $HTTP_BAD_REQUEST
        );
    }
    else {
        my $todos = Devel::Explorer::ToDo->new(
            todos     => $todo_list->{todos},
            module    => $todo_list->{module},
            explorer  => $explorer,
            no_critic => $no_critic
        );

        my $retval = eval { return $todos->save_todos($no_critic); };

        my $error = $EVAL_ERROR // $EMPTY;

        my $status = $retval ? $HTTP_OK : $SERVER_ERROR;

        output_json(
            $r,
            {   status     => $status,
                error      => $error,
                html_error => to_html($error),
            },
            $status,
        );

    }

    return $OK;
}

########################################################################
sub api_search {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ($explorer) = @{$options}{qw(explorer)};

    my $req = Apache2::Request->new($r);

    my $repo_search = $req->param('repo-search');
    my $is_regexp   = $req->param('regexp');
    my $search_term = $req->param('search-term');
    my $module      = $req->param('module');

    my $source = eval { return fetch_source_from_module( explorer => $explorer, module => $module ); };

    if ( !$source || $EVAL_ERROR ) {
        output_json( $r, { error => 'not found' }, $NOT_FOUND );
        return $OK;
    }

    my $source_explorer = Devel::Explorer::Search->new( source => $source );

    my $term_type = $is_regexp ? 'regexp' : 'text';

    my $result;

    my %package_names = reverse %{ $explorer->get_package_names };

    if ($repo_search) {
        $result = $source_explorer->search_all(
            explorer   => $explorer,
            $term_type => $search_term,
            callback   => sub {
                my ( $file, $results ) = @_;

                my $package_name = $package_names{$file};

                if ( !$package_name ) {
                    carp 'no package name for ' . $file;
                }

                $results->{$file} = [ $results->{$file}, $package_name ];

                return;
            }

        );

        my $modules = [];

        if ( %{$result} ) {
            foreach my $file ( keys %{$result} ) {
                push @{$modules}, $result->{$file};
            }

            $result = [ sort { $a->[1] cmp $b->[1] } @{$modules} ];
        }
    }
    else {
        $result = $source_explorer->search( $term_type => $search_term );
    }

    output_json( $r, $result );

    return $OK;
}

########################################################################
sub api_source_lines {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $module ) = @{$options}{qw(explorer module)};

    my $req = Apache2::Request->new($r);

    my $lines = $req->param('lines');

    my $line_number = $req->param('line_number');

    my $source = eval { return fetch_source_from_module( explorer => $explorer, module => $module ); };

    if ( !$source || $EVAL_ERROR ) {
        output_json( $r, { error => 'not found' }, $NOT_FOUND );
        return $OK;
    }

    my $source_explorer = Devel::Explorer::Source->new(
        config   => $explorer->get_config,
        source   => $source,
        explorer => $explorer,
    );

    my $highlighted_source = $source_explorer->highlight_source_lines();

    $highlighted_source = around_lines( $highlighted_source, $lines, $line_number );

    # TODO: class names should be a configurable option
    if ($line_number) {
        my $line_to_highlight = -1 + $lines;
        my $line              = $highlighted_source->[$line_to_highlight];
        if ( $line =~ /pe\-critic\-context/xsm ) {
            $line =~ s/pe\-critic\-context/pe-critic-context pe-critic-context-line/xsm;
            $highlighted_source->[$line_to_highlight] = $line;
        }
    }

    output_json( $r, $highlighted_source );

    return $OK;
}

########################################################################
sub api_add_pod {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $module ) = @{$options}{qw(explorer module)};

    my $pod_len = $explorer->has_pod($module);

    if ($pod_len) {
        my $error = {
            error   => sprintf( '%s already has POD', $module ),
            uri     => $r->uri,
            context => {
                module  => $module,
                pod_len => $pod_len,
            }
        };

        return api_error( $r, $error, $HTTP_BAD_REQUEST );
    }

    my $html = eval { return pod( $r, module => $module, add => $TRUE, explorer => $explorer, ); };

    if ( !$html || $EVAL_ERROR ) {
        my $error = {
            error   => $EVAL_ERROR,
            uri     => $r->uri,
            context => {
                module => $module,
                add    => $TRUE,
            }
        };

        return api_error( $r, $error, $SERVER_ERROR );
    }
    else {
        my $resp = {
            status => $HTTP_OK,
            uri    => '/explorer/pod/' . $module,
            module => $module,
        };

        output_json( $r, $resp );
    }

    return $OK;
}

########################################################################
sub show_pod {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $explorer, $module ) = @{$options}{qw(explorer module)};

    my $req = Apache2::Request->new($r);
    my $add = $req->param('add');

    return api_add_pod( $r, @args )
      if $add;

    my $html = eval { return pod( $r, module => $module, add => $add, explorer => $explorer, ); };

    return html_error(
        $r,
        explorer => $explorer,
        msg      => 'no pod found',
        status   => $NOT_FOUND
    ) if !$html || $html =~ /<body[^>]+>(\s+)<\/body>/xsm;

    output_html( $r, $html );

    return $OK;
}

########################################################################
sub api_error {
########################################################################
    my ( $r, $error, $status ) = @_;

    $status //= $HTTP_BAD_REQUEST;

    if ( !ref $error ) {
        $error = {
            error  => $error,
            status => $status
        };
    }

    $error->{status} = $status;

    output_json( $r, $error, $status );

    return $OK;
}

########################################################################
sub explorer {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ($explorer) = @{$options}{qw(explorer)};

    my $index;

    if ( $explorer->get_repo ) {
        $explorer->set_tree( { $ROOT_NODE => $explorer->get_tree } );
        my $root = '/perl-explorer/' . $explorer->get_repo;

        $index = $explorer->directory_index($root);
    }
    else {
        my $config        = $explorer->get_config;
        my $repo_template = slurp_file $config->{templates}->{repo_index};

        $index = tt_process(
            $repo_template,
            {   repo_listing => $config->{repo},
                js           => fix_path( $config->{site}->{js},  $config->{repo_index}->{js} ),
                css          => fix_path( $config->{site}->{css}, $config->{repo_index}->{css} ),
                logo         => $config->{site}->{logo},
            }
        );
    }

    output_html( $r, $index );

    return $OK;
}

########################################################################
sub html_error {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $msg, $status, $explorer, $context ) = @{$options}{qw(msg status explorer context)};

    my $logo;
    my $config;
    my $error_template;

    if ($explorer) {
        $config         = $explorer->get_config;
        $logo           = $config->{site}->{logo};
        $error_template = slurp_file $config->{templates}->{error};
    }
    else {
        $error_template = <<'END_OF_HTML';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Perl Explorer - Error]</title>
  </head>
  
  <body>
    [% IF logo %]
    <div id="header">
      <img src="[% logo %]">
    </div>
    [% END %]

   <div class="error">
    [% message %]
   </div>
   <pre>
    [% context.error %]
   </pre>

  </body>
</html>
END_OF_HTML
    }

    my $params = {
        logo    => $logo // $EMPTY,
        message => $msg,
        context => $context,
        config  => $explorer
    };

    my $output = tt_process( $error_template, $params );

    output_html( $r, $output );

    return $status || $OK;
}

########################################################################
sub init_explorer {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $config_file, $repo ) = @{$options}{qw(config_file repo)};

    $config_file //= $ENV{CONFIG};

    die "no config file\n"
      if !$config_file;

    die "could not find '$config_file'\n"
      if !-e $config_file;

    my $explorer = Devel::Explorer->new( config_file => $config_file, repo => $repo );

    return $explorer;
}

########################################################################
sub get_module_directory {
########################################################################
    my ($path) = @_;

    my @modules;

    find(
        sub {
            return if $_ !~ /[.]pm$/xsm;

            push @modules, $File::Find::name;
        },
        $path,
    );

    my %directory;

    foreach my $m (@modules) {
        $m =~ s/$path\///xsm;

        my ( undef, $name ) = ( split /\//xsm, $m );

        my $letter = substr $name, 0, 1;

        $directory{$letter} //= [];

        push @{ $directory{$letter} }, $m;
    }

    return \%directory;
}

########################################################################
sub create_tree {
########################################################################
    my ($modules) = @_;

    my %tree;

    foreach my $m ( @{$modules} ) {
        my ( $prefix, $node, @rest ) = split /::/xsm, $m;

        $tree{$prefix} = [];

        if ($node) {
            $prefix = "${prefix}::$node";
            $tree{$prefix} = [];
        }

        pop @rest;

        foreach (@rest) {
            $prefix = "${prefix}::$_";
            $tree{$prefix} = [];
        }
    }

    foreach my $m ( @{$modules} ) {
        foreach my $prefix ( keys %tree ) {
            next if $m !~ /^${prefix}::[^:]+$/xsm;

            push @{ $tree{$prefix} }, $m;
        }
    }

    return \%tree;
}

########################################################################
sub show_index {
########################################################################
    my ( $r, $letter ) = @_;

    $letter //= 'A';

    $letter = uc $letter;

    my $directory = get_module_directory('/app/lib');

    my $li = join "\n", map { sprintf '<li class="alpha-navbar"><a href="/pod/%s">%s</a></li>', $_, $_ } ( 'A' .. 'Z' );

    my $listing = $directory->{$letter} // [];

    my @modules = @{$listing};

    foreach (@modules) {
        while (s/\//::/gxsm) { }
        s/[.]pm$//xsm;
    }

    my $tree = create_tree( \@modules );
    my @branches;

    foreach my $node ( keys %{$tree} ) {
        if ( any { $node eq $_ } @modules ) {
            #            push @branches, qq{<a href="/pod/$node">$node</a><br>};
        }
        else {
            push @branches, "$node<br>";
        }
    }

    my $alpha_listing = join q{}, @branches;

    my $html = <<"END_OF_HTML";
<html>
  <head>
     <link rel="stylesheet" type="text/css" href="/static/css/pod.css" />
  </head>
  <body>
    <div class="alpha-navbar">
    <ul>
    $li
    </ul>
    <div>
    $alpha_listing
    </div>
  </body>
</html>
END_OF_HTML

    output_html( $r, $html );

    return $OK;
}

########################################################################
sub show_source {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $id, $explorer ) = @{$options}{qw(id explorer)};

    my $file_info = $explorer->get_file_info->{$id};

    if ( !$file_info ) {
        html_error(
            $r,
            msg      => "$id not found",
            explorer => $explorer,
            status   => $NOT_FOUND
        );

        return $OK;
    }

    my $config = $explorer->get_config;

    my ($module) = eval {
        my $package_names = $file_info->{package_name};

        return
          if !$package_names;

        return $package_names->[0]
          if @{$package_names} == 1;

        my $filename = $file_info->{name};

        return grep {/${filename}$/xsm} @{$package_names};
    };

    my $filename = join $EMPTY, @{$file_info}{qw(name ext)};

    my $inputlang = $SOURCE_HIGHLIGHT_MAP{ $file_info->{ext} } // 'nohilite.lang';

    my $source_explorer = Devel::Explorer::Source->new(
        explorer     => $explorer,
        config       => $config,
        module       => $module,
        file         => $file_info->{vpath},
        inputlang    => $inputlang,
        use_template => $TRUE,
    );

    my $source = $source_explorer->get_source;

    my $dependencies;

    if ( $module || $file_info->{ext} eq '.pl' ) {
        $dependencies = $source_explorer->create_dependency_listing($id);
    }

    my $todos = 0;

    while ( $source =~ /[#][#]\sno\scritic[^\n]+\n/xsgm ) { ++$todos; }
    while ( $source =~ /[#][#]\sTODO[^\n]+\n/xsgm )       { ++$todos; }

    my $req = Apache2::Request->new($r);

    my $linenum = $req->param('linenum') // 1;

    output_html(
        $r,
        $source_explorer->highlight(
            module       => $module,
            filename     => $filename,
            dependencies => $dependencies,
            todos        => $todos,
            linenum      => $linenum,
        )
    );

    return $OK;
}

########################################################################
sub show_critique {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $module, $explorer ) = @{$options}{qw(module explorer)};
    my $config = $explorer->get_config;

    my $critique = eval { critique( module => $module, explorer => $explorer ); };

    if ( !$critique || $EVAL_ERROR ) {
        return api_error( $r, $EVAL_ERROR, $SERVER_ERROR );
    }

    my $req     = Apache2::Request->new($r);
    my $display = $req->param('display');

    if ($display) {
        my $html = $critique->{critic}->render_violations();

        output_html( $r, $html );
    }
    else {
        delete $critique->{critic};

        output_json( $r, $critique );
    }

    return $OK;
}

########################################################################
sub critique {
########################################################################
    my @args = @_;

    my $options = get_args(@args);

    my ( $module, $explorer ) = @{$options}{qw(module explorer)};
    my $config = $explorer->get_config;

    my $source = fetch_source_from_module( explorer => $explorer, module => $module );

    my $critic = Devel::Explorer::Critic->new(
        module => $module,
        config => $config,
        source => $source,
    );

    my $violations = $critic->critique();

    $critic->set_violations($violations);
    $critic->set_statistics( $critic->get_critic->statistics );

    my $stat_summary = $critic->create_stat_summary();

    # see if this module has pod
    $stat_summary->{has_pod} = $explorer->has_pod($module);

    my $source_explorer = Devel::Explorer::Source->new( source => $source, config => $config );

    # get the list of dependencies
    $stat_summary->{dependency_listing} = $source_explorer->create_dependency_listing(
        explorer => $explorer,
        source   => $source,
        module   => $module,
    );

    # see if module is tidy
    $stat_summary->{is_tidy} = Devel::Explorer::Tidy->new(
        source => $source,
        config => $config->{tidy},
    )->tidy();

    my $violation_summary = $critic->create_violation_summary();

    return {
        summary    => $stat_summary,
        module     => $module,
        violations => $violation_summary,
        critic     => $critic,
    };
}

########################################################################
sub pod {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $module, $explorer, $add ) = @{$options}{qw(module explorer add)};

    my %modules = %{ $explorer->get_modules || {} };

    my $config = $explorer->get_config;

    my $css_url = sprintf '%s/%s', $config->{site}->{css}, $config->{pod}->{css};

    my @extra_paths = split /:/xsm, $config->{perl5lib};

    my $id = $modules{$module};

    my $file = $id ? $explorer->get_file_info->{$id}->{vpath} : find_module( $r, $module, @extra_paths );
    return
      if !$file;

    if ($add) {
        add_pod( file => $file, append => 1, config => $config );
    }

    my $pod = tmpnam;

    my %options = (
        '--infile'   => $file,
        '--outfile'  => $pod,
        '--cachedir' => File::Spec->tmpdir(),
        $css_url ? ( '--css' => $css_url ) : (),
    );

    my $html = eval {
        pod2html( '--backlink', map { "$_=" . $options{$_} } keys %options );

        return slurp_file($pod);
    };

    if ( !$html || $EVAL_ERROR ) {
        $r->log->error("pod2html error: $EVAL_ERROR");
    }

    if ( -e $pod ) {
        unlink $pod;
    }

    return $html;
}

########################################################################
sub output_json {
########################################################################
    my ( $r, $content, $status ) = @_;

    return _output(
        $r,
        content_type => 'application/json',
        content      => $content,
        status       => $status,
    );
}

########################################################################
sub output_html {
########################################################################
    my ( $r, $content, $status ) = @_;

    return _output(
        $r,
        content_type => 'text/html',
        content      => $content,
        status       => $status,
    );
}

########################################################################
sub _output {
########################################################################
    my ( $r, @args ) = @_;

    my $options = get_args(@args);

    my ( $status, $content_type, $content, $pretty )
      = @{$options}{qw(status content_type content pretty)};

    $pretty //= $TRUE;  # default is pretty

    $content_type //= 'text/html';

    $status //= $HTTP_OK;

    if ($status) {
        $r->status($status);
    }

    $r->content_type($content_type);

    if ( $content_type eq 'application/json' && ref $content ) {
        $content = JSON->new->pretty($pretty)->encode($content);
    }

    $r->send_http_header;

    return print $content;
}

1;

__DATA__

=pod

=head1 NAME

Apache::Devel::Explorer

=head1 SYNOPSIS

 <Location /explorer>
    PerlSetEnv CONFIG /app/perl-explorer.json
    PerlSetEnv TT_INCLUDE_PATH /usr/local/share/perl-explorer/

    SetHandler perl-script

    PerlResponseHandler Apache::Devel::Explorer
 </Location>

=head1 DESCRIPTION

A web application to help those maintaining legacy Perl
applications. This app will allow you to:

=over 5

=item * navigate a source tree of Perl modules

=item * search the repository

=item * view source code

=item * execute Perl critic and view detail or summary results

=item * add TODOs to the module based on L<Perl::Critic> findings or
other issues

=item * add POD templates to modules

=item * view Perl documentation of local or CPAN modules

=item * view markdown files in your source tree

=item * tidy Perl code

=back

=head1 AUTHOR

BIGFOOT - <bigfoot@cpan.org>

=head1 SEE OTHER

L<Perl::Critic>, L<Syntax::SourceHighlight>, L<Markdown::Render>

=cut
