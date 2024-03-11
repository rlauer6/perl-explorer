package Devel::Explorer::Tidy;

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
use Data::Dumper;
use Devel::Explorer::Utils qw(:all);
use Digest::MD5            qw(md5_hex);
use File::Temp             qw(tempfile);
use English                qw(-no_match_vars);
use IO::Scalar;
use Perl::Tidy;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
  qw(
    config
    file
    profile
    source
    statistics
  )
);

use parent qw(Devel::Explorer::Base);

caller or __PACKAGE__->main();

########################################################################
sub set_defaults {
########################################################################
  my ($self) = @_;

  my $config = $self->get_config;

  $self->set_config( $config // {} );

  my $profile = $self->get_profile // $config->{profile};

  if ( !$profile && $ENV{HOME} ) {

    $profile = "$ENV{HOME}/.perltidyrc";

    if ( !-e $profile ) {
      undef $profile;
    }
  }

  $self->set_profile($profile);

  return $self;
}

########################################################################
sub tidy {
########################################################################
  my ( $self, @args ) = @_;

  my $options = get_args(@args);
  my ( $source, $file, $save ) = @{$options}{qw(source file save)};

  $source //= $self->get_source;

  if ( !$source ) {
    $file //= $self->get_file;

    $source = slurp_file($file);
  }

  my $md5_untidy = md5_hex($source);

  die 'usage: tidy(source)'
    if !$source;

  my ( $fh, $tempfile ) = tempfile();
  close $fh;

  my $profile = $self->get_profile;
  carp "no perltidy profile defined\n"
    if !$profile;

  carp "cannot find $profile\n"
    if !-e $profile;

  my $errstr = $EMPTY;

  my $stderr = IO::Scalar->new( \$errstr );

  my $argv = sprintf '-o %s %s', $tempfile, $profile ? "-pro=$profile" : $EMPTY;

  # 0 = good, 1 = problem with args,  2 = perltidy had errors with input
  my $error = eval { return Perl::Tidy::perltidy( argv => $argv, source => \$source, ); };

  die "error executing perltidy\n$EVAL_ERROR\n"
    if !defined $error || $EVAL_ERROR;

  if ($error) {
    die "problem with perltidy parameters\n"
      if $error == 1;

    die "problem with input\n"
      if $error == 2;
  }

  my $tidy_source = slurp_file($tempfile);

  my $is_tidy = md5_hex($tidy_source) eq $md5_untidy;

  if ( !$save ) {
    unlink $tempfile;
  }
  elsif ( !$is_tidy && $file ) {

    my $backup = $file;
    $backup =~ s/[.]pm$/.bak/xsm;

    unlink $backup;  # remove if it exists

    rename $file, $backup
      or die "could not create backup file : $OS_ERROR\n";

    eval { rename $tempfile, $file; };

    if ( my $err = $EVAL_ERROR ) {
      rename $backup, $file;  # revert file!

      die "could not create tidy file! $err\n";

      return $FALSE;
    }

    chmod 0666, $file;

    return $TRUE;
  }

  return $is_tidy;
}

########################################################################
sub main {
########################################################################
  my ( $file, $save ) = @ARGV;

  my $tidy = Devel::Explorer::Tidy->new(
    file => $file,
    save => $save,
  );

  printf "is %s tidy: %s\n", $file, $tidy->tidy( save => $save ) ? 'YES' : 'NO';

  return 0;
}

1;
