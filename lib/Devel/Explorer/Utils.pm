package Devel::Explorer::Utils;

use strict;
use warnings;

use Data::Dumper;
use File::Temp qw(tempfile);
use File::Copy;

use English qw(-no_match_vars);
use File::Find;
use File::Basename qw(fileparse);
use JSON;
use List::Util qw(sum any);
use Template;
use Text::Wrap;
use Scalar::Util qw(reftype);
use Carp;
use Carp::Always;
use Readonly;

Readonly::Scalar our $DOUBLE_COLON => q{::};
Readonly::Scalar our $EMPTY        => q{};
Readonly::Scalar our $COMMA        => q{,};
Readonly::Scalar our $PERIOD       => q{.};
Readonly::Scalar our $SPACE        => q{ };

Readonly::Scalar our $TRUE  => 1;
Readonly::Scalar our $FALSE => 0;

Readonly::Scalar our $DEFAULT_INCLUDE_PATH => '/usr/loca/share/perl-explorer';

Readonly::Hash our %SOURCE_HIGHLIGHT_MAP => (
    '.xml'      => 'xml.lang',
    '.am'       => 'makefile.lang',
    '.sh'       => 'sh.lang',
    'ChangeLog' => 'changelog.lang',
    '.conf'     => 'conf.lang',
    '.pl'       => 'perl.lang',
    '.pm'       => 'perl.lang',
    '.php3'     => 'php.lang',
    '.php4'     => 'php.lang',
    '.php5'     => 'php.lang',
    '.py'       => 'py.lang',
    '.html'     => 'html.lang',
    '.roc'      => 'html.lang',
    '.css'      => 'css.lang',
    '.js'       => 'js.lang',
    '.log'      => 'log.lang',
    '.m4'       => 'm4.lang',
    '.spec'     => 'spec.lang',
);

our %EXPORT_TAGS = (
    funcs => [
        qw(
          add_pod
          get_args
          create_backup
          fetch_ignore_list
          fetch_source_from_module
          find_requires
          fix_path
          is_array
          is_hash
          replace_file
          slurp_file
          slurp_json
          to_html
          tt_process
          dbg
        )
    ],
    booleans => [
        qw(
          $TRUE
          $FALSE
        )
    ],
    chars => [
        qw(
          $COMMA
          $DOUBLE_COLON
          $EMPTY
          $PERIOD
          $SPACE
        )
    ],
    maps => [
        qw(
          %SOURCE_HIGHLIGHT_MAP
        )
    ],
);

$EXPORT_TAGS{all} = [ map { @{ $EXPORT_TAGS{$_} } } keys %EXPORT_TAGS ];

our @EXPORT_OK = @{ $EXPORT_TAGS{all} };

use parent qw(Exporter);

caller or __PACKAGE__->main();

########################################################################
sub is_hash {
########################################################################
    my ($obj) = @_;

    return $obj && reftype($obj) eq 'HASH';
}

########################################################################
sub is_array {
########################################################################
    my ($obj) = @_;

    return $obj && reftype($obj) eq 'ARRAY';
}

########################################################################
sub to_html {
########################################################################
    my ( $str, $options ) = @_;

    $str =~ s/\n/<br\/>/xsmg;

    return $str;
}

########################################################################
sub slurp_file {
########################################################################
    my ($file) = @_;

    local $RS = undef;

    open my $fh, '<', $file
      or die "could not open $file for reading: $OS_ERROR";

    my $content = <$fh>;

    close $fh;

    return wantarray ? split /\n/xsm, $content : $content;
}

########################################################################
sub slurp_json {
########################################################################
    my ($file) = @_;

    my $content = slurp_file($file);

    my $obj = JSON->new->decode($content);

    return $obj;
}

########################################################################
sub find_requires {
########################################################################
    my ($source) = @_;

    require Module::ScanDeps::Static;

    my $scanner = Module::ScanDeps::Static->new();

    return [ $scanner->parse( \$source ) ];
}

########################################################################
sub tt_process {
########################################################################
    my ( $source, $params ) = @_;

    my $include_path = $ENV{TT_INCLUDE_PATH} // $DEFAULT_INCLUDE_PATH;
    $include_path = [ split /:/xsm, $include_path ];

    my $tt = Template->new( { INTERPOLATE => 1, INCLUDE_PATH => $include_path } );

    my $output = q{};

    $tt->process( \$source, $params, \$output )
      or die $tt->error();

    return $output;
}

########################################################################
sub fetch_ignore_list {
########################################################################
    my ( $path, $list ) = @_;

    if ( $list && !ref $list && -e "$path/$list" ) {
        $list = eval { return [ split /\n/xsm, slurp_file "$path/$list" ]; };
    }
    elsif ( !ref $list ) {
        $list = [$list];
    }

    return @{ $list || [] };
}

########################################################################
sub fetch_source_from_module {
########################################################################
    my @args = @_;

    my $options = get_args(@args);

    my ( $explorer, $module ) = @{$options}{qw(explorer module)};

    die "usage: fetch_source_from_module(explorer => explorer, module => module)\n"
      if !$explorer || !$module;

    my $file = $explorer->get_file_by_module($module);

    return slurp_file($file);
}

########################################################################
sub get_args { return ref $_[0] ? $_[0] : {@_}; }
########################################################################

########################################################################
sub create_backup {
########################################################################
    my ($file) = @_;

    my $backup = "$file.bak";

    if ( -e $backup ) {
        unlink $backup;  # remove if it exists
    }

    return rename( $file, $backup ) ? $backup : $EMPTY;
}

########################################################################
sub dbg {
########################################################################
    return print {*STDERR} Dumper( \@_ );
}

########################################################################
sub replace_file {
########################################################################
    my (@args) = @_;

    my ($options) = get_args(@args);

    my ( $source, $infile, $outfile, $unlink ) = @{$options}{qw(source infile outfile unlink)};

    my $backup = create_backup($infile);

    if ( !$backup ) {
        die "error creating backup file: $OS_ERROR\n";
    }

    if ($source) {
        my ( $fh, $tmpnam ) = tempfile();
        $outfile = $tmpnam;

        print {$fh} $source;

        close $fh;

        $unlink //= $TRUE;
    }

    if ( !copy( $outfile, $infile ) ) {
        rename $backup, $infile;

        die sprintf "error creating %s: %s\n", $infile, $OS_ERROR;
    }
    elsif ($unlink) {
        unlink $outfile;
    }

    chmod 0666, $infile;

    return $infile;
}

########################################################################
sub add_pod {
########################################################################
    my @args = @_;

    my $options = get_args(@args);

    my ( $file, $append, $config ) = @{$options}{qw(file append config)};

    my $pod = create_pod($options);

    replace_file( infile => $file, source => $pod );

    return $TRUE;
}

# add path to relative files, returns a new list of files
########################################################################
sub fix_path {
########################################################################
    my ( $path, @files ) = @_;

    my @paths = ref $files[0] ? @{ $files[0] } : @files;

    foreach my $f ( grep {defined} @paths ) {
        next if $f =~ /^\//xsm;
        $f = "$path/$f";
    }

    return \@paths;
}

########################################################################
sub create_pod {
########################################################################
    my @args = @_;

    my $options = get_args(@args);

    my ( $file, $source, $config, $module ) = @{$options}{qw(file source config module)};

    $config //= {};

    my $author = $config->{pod}->{author};

    if ( !$source ) {
        $source = slurp_file $file;
    }

    die 'no source'
      if !$source;

    if ( !$module && $source =~ /^package\s+([^;]+);/xsm ) {
        $module = $1;
    }

    my @subs;

    my $see_also = find_requires($source);

    while ( $source =~ /^sub\s+([^{ \n]+)/xsmg ) {
        push @subs, $1;
    }

    local $Text::Wrap::columns = 72;

    my $see_also_pod = wrap( $EMPTY, $EMPTY, join "$COMMA ", map { sprintf 'L<%s>', $_ } @{$see_also} );

    my $params = {
        module   => $module // 'No::Name',
        subs     => [ sort @subs ],
        author   => $author // 'anonymouse',
        see_also => $see_also_pod,
    };

    my $pod_tpl = <<'END_OF_POD';
=pod

=head1 NAME

[% module %]

=head1 SYNOPSIS

 my $foo = [% module %]->new();

=head1 DESCRIPTION

TODO - add description

=head1 METHODS AND SUBROUTINES

TODO - documents methods and subroutines

[% FOREACH name IN subs %]
=head2 [% name %]
[% END -%]

=head1 SEE ALSO

[% see_also %]

=head1 AUTHOR

[% author %]

=cut
END_OF_POD

    my $pod = tt_process( $pod_tpl, $params );

    return $options->{append} ? "$source\n$pod" : $pod;
}

########################################################################
sub main {
########################################################################
    my $file = shift @ARGV;

    print add_pod( file => $file, append => 1 );

    return;
}

1;

