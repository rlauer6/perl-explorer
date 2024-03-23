#!/usr/bin/perl

package Devel::Explorer::Configure;

use strict;
use warnings;

BEGIN {
    use lib 'lib';
}

use Carp;
use Cwd;
use Devel::Explorer::Utils qw(:all);
use English qw(-no_match_vars);
use JSON;
use Template;

use Readonly;

Readonly::Scalar our $DEFAULT_CONFIG => 'defaults.json';
Readonly::Scalar our $DEFAULT_PORT   => '8080';

use parent qw(CLI::Simple);

########################################################################
sub init {
########################################################################
    my ($self) = @_;

    return $TRUE;
}

########################################################################
sub configure {
########################################################################
    my ($self) = @_;

    croak "--repo is a required argument\n"
      if !$self->get_repo;

    my $cwd = getcwd;

    my $config_file = $self->get_config // 'defaults.json';

    die "no config file\n"
      if !-e $config_file;

    my $config = eval { slurp_json($config_file); };

    die "unable to read $config_file\n$EVAL_ERROR"
      if !$config;

    foreach (qw(datadir perl5libdir config_template files)) {
        die "no $_ defined in config file\n"
          if !$config->{$_};
    }

    my $file_list = $config->{files};

    my $repo = $self->get_repo // $config->{repo};

    carp "the repo path does not exist\n"
      if !$repo || !-d $repo;

    $config->{docker}->{repo} //= $repo;

    my $params = $config;

    $params->{document_root}    = $self->get_sitedir  // $config->{site}->{document_root};
    $params->{repo}             = $self->get_repo     // $config->{repo};
    $params->{datadir}          = $self->get_datadir  // $config->{datadir};
    $params->{docker}->{port}   = $self->get_port     // $config->{docker}->{port};
    $params->{markdown}->{path} = $self->get_markdown // $config->{markdown};
    $params->{markdown}->{path} //= $params->{repo};

    my $template = slurp_file( $config->{config_template} );

    my $new_config = tt_process( $template, $params );

    $new_config = JSON->new->decode($new_config);

    $self->logger( sprintf "saving new configuration file: %s\n", $file_list->{ $config->{config_template} } );

    $self->save( $file_list->{ $config->{config_template} }, $new_config );

    return 0
      if $self->get_config_only;

    foreach my $template_file ( keys %{$file_list} ) {
        next if $template_file eq $config->{config_template};

        $self->logger( sprintf "processing %s...\n", $template_file );

        my $template = slurp_file($template_file);
        if ( $template_file !~ /[.css]/xsm ) {
            $template =~ s/^[#][^\n]*\n//xsmg;
        }

        my $dest = $file_list->{$template_file};
        $self->save( $dest, tt_process( $template, $new_config ) );

        $self->logger( sprintf "...processed %s\n", $dest );
    }

    return 1;
}

########################################################################
sub logger {
########################################################################
    my ( $self, $message ) = @_;

    return
      if $self->get_quiet;

    return print {*STDERR} sprintf '%s: %s', $PROGRAM_NAME, $message;
}

########################################################################
sub save {
########################################################################
    my ( $self, $file, $content ) = @_;

    create_backup($file);

    if ( ref $content ) {
        $content = JSON->new->pretty($TRUE)->encode($content);
    }

    open my $fh, '>', $file
      or croak "could not open $file for writing\n$OS_ERROR";

    print {$fh} $content;

    return close $fh;
}

########################################################################
sub main {
########################################################################

    my @option_specs = qw(
      help
      repo|r=s
      markdown|m=s
      sitedir=s
      datadir=s
      config=s
      port=s
      config-only|C
      quiet
    );

    Getopt::Long::Configure('no_ignore_case');

    return __PACKAGE__->new(
        option_specs    => \@option_specs,
        extra_options   => [],
        default_options => {
            port   => $DEFAULT_PORT,
            config => $DEFAULT_CONFIG,
        },
        commands => { configure => \&configure, },
    )->run;
}

exit main();

1;

## no critic

=pod

=head1 NAME

perl-explorer

=head1 DESCRIPTION

=head1 RUNNING IN A DOCKER CONTAINER

I<perl-explorer> can be run in a Docker container or within your
development environment if you have an Apache server available. You
can run the Docker image created by this project or you run
I<perl-explorer> in an existing Docker container that contains an
Apache web server.

=head2 Building and using perl-explorer's container

=over 5

=item 1. Build the I<perl-base> Docker image

 make perl-base

=item 2. Build the I<perl-explorer> Docker image

 make perl-explorer

=item 3. Configure I<perl-explorer>

 configure.pl --config my-config.json

=item 4. Bring up the container

 cd docker
 docker-compose up
 
=back

=head1 USAGE

 configure.pl Options

 This is the configuration script for 'perl-explorer'.

 See man perl-explorer for a detailed explanation of configuration values.

 * Edit the reference 'defaults.json' file to set the paths and features
 for your environment or clone the file and save your own defaults
 file.

 * Create the final configuration and template files used by
 'perl-explorer' ('perl-explorer.json') by running 'configure.pl'

 * Install 'perl-explorer' using the Makefile

   make -f Makefile 

 Options
 ------
 --help, -h         this
 --config, -c       configuration file
 --repo, -r         real path to Perl modules
 --sitedir, -s      path to Apache's document root
 --datadir, -d      path where perl-explorer resource files are installed
 --port, -p         port to expose when running perl-explorer in a Docker container
 --config-only, -c  only create the perl-explorer.json file

=cut
