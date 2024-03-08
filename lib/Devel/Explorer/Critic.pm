package Devel::Explorer::Critic;

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
use Perl::Critic;

__PACKAGE__->follow_best_practice;

__PACKAGE__->mk_accessors(
    qw(
      config
      critic
      file
      module
      profile
      severity
      source
      statistics
      template
      theme
      verbose
      violations
      violation_summary
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

    my $config = $self->get_config;

    $self->set_config( $config // {} );

    foreach (qw(severity theme verbose profile)) {
        $self->set( $_, $self->get($_) // $config->{critic}->{$_} );
    }

    $self->set_severity( $self->get_severity // 1 );
    $self->set_verbose( $self->get_verbose   // 11 );
    $self->set_theme( $self->get_theme       // 'pbp' );

    if ( !$self->get_profile && $ENV{HOME} ) {
        my $profile = "$ENV{HOME}/.perlcriticrc";
        if ( -e $profile ) {
            $self->set_profile($profile);
        }
    }

    $self->set_template( $self->get_template // $DEFAULT_TEMPLATE );

    return $self;
}

########################################################################
sub critique {
########################################################################
    my ( $self, $source ) = @_;

    $source //= $self->get_source;

    if ( !$source && $self->get_file ) {
        $source = slurp_file( $self->get_file );
    }

    die 'usage: critique(source)'
      if !$source;

    my $critic = Perl::Critic->new(
        -profile  => $self->get_profile,
        -severity => $self->get_severity,
        -verbose  => $self->get_verbose,
        -theme    => $self->get_theme,
    );

    $self->set_critic($critic);

    my @violations = $critic->critique( \$source );

    $self->set_violations( \@violations );

    return \@violations;
}

########################################################################
sub create_stat_summary {
########################################################################
    my ($self) = @_;

    die 'run critique first'
      if !$self->get_critic || !$self->get_violations;

    my $stats = $self->get_critic->statistics;

    my $summary = {
        subs           => $stats->subs(),
        statements     => $stats->statements(),
        lines_of_perl  => $stats->lines_of_perl(),
        violations     => $stats->violations_by_severity(),
        policies       => $stats->violations_by_policy(),
        total          => $stats->total_violations(),
        avg_complexity => sprintf '%5.2f',
        $stats->average_sub_mccabe(),
    };

    foreach ( 1 .. 5 ) {
        $summary->{violations}->{$_} //= 0;
    }

    return $summary;
}

########################################################################
sub create_violation_summary {
########################################################################
    my ($self) = @_;

    die 'run critique first'
      if !$self->get_critic || !$self->get_violations;

    my $violations = $self->get_violations();

    my @summary;
    my %diagnostics;

    foreach ( @{$violations} ) {
        my $violation = {
            summary       => $_->to_string(),
            line_number   => $_->line_number(),
            column_number => $_->visual_column_number(),
            severity      => $_->severity(),
            policy        => $_->policy(),
            source        => $_->source(),
            description   => $_->description(),
        };

        $diagnostics{ $_->policy() } = $_->diagnostics();

        push @summary, $violation;
    }

    # find todos
    my @source_lines = split /\n/xsm, $self->get_source;

    my @todos = grep { $source_lines[ $_ - 1 ] =~ /\s[#][#]\sno\scritic/xsm } ( 1 .. @source_lines );
    @todos = map { sprintf '%04d', $_ } @todos;

    my $violation_summary = {
        summary     => \@summary,
        diagnostics => \%diagnostics,
        todos       => { map { $_ => 'pe-critic-todo' } @todos },
    };

    $self->set_violation_summary($violation_summary);

    return $violation_summary;
}

########################################################################
sub create_snippet {
########################################################################
    my ( $text, $len, $class ) = @_;

    my $snippet = $text;

    if ( length $text > $len + 3 ) {
        $snippet = substr $snippet, 0, $len;
        $snippet = "$snippet...";
    }

    $snippet = sprintf '<span class="%s">%s</span>', $class, $snippet;

    return $snippet;
}

########################################################################
sub render_violations {
########################################################################
    my ($self) = @_;

    die "run critique() first\n"
      if !$self->get_violations;

    my $violations = $self->create_violation_summary();

    foreach ( @{ $violations->{summary} } ) {
        $_->{line_number}   = sprintf '%04d', $_->{line_number};
        $_->{column_number} = sprintf '%03d', $_->{column_number};
        $_->{policy_short}  = $_->{policy};
        $_->{policy_short} =~ s/Perl::Critic::Policy:://xsm;
        $_->{source_snippet}      = create_snippet( $_->{source},      25, 'source-snippet' );
        $_->{description_snippet} = create_snippet( $_->{description}, 60, 'description-snippet' );

        if ( length $_->{description} <= 60 ) {
            delete $_->{description};
        }
        if ( length $_->{source} <= 25 ) {
            delete $_->{source};
        }
    }

    my $config = $self->get_config;

    $violations->{summary} = $violations->{summary};

    my $params = {
        img => {
            up   => '/icons/up.png',
            down => '/icons/down.png',
        },
        module      => $self->get_module,
        todos       => $violations->{todos},
        violations  => $violations->{summary},
        diagnostics => $violations->{diagnostics},
        js          => fix_path( $config->{site}->{js},  $config->{critic}->{js} ),
        css         => fix_path( $config->{site}->{css}, $config->{critic}->{css} ),
    };

    return tt_process( $self->get_template, $params );
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
    <div id="pe-status-message">
      <span></span><button>ok</button>
    </div>

    <input id="pe-save-button" type="button" value="Save" />
  
    <table id="critic" class="display">
      <thead>
        <tr>
          <th>Line</th>
          <th>Col</th>
          <th>Severity</th>
          <th>Policy</th>
          <th>Source</th>
          <th>Description</th>
        </tr>
      </thead>

      <tbody>
      [% FOREACH v IN violations %]
        <tr>
          <td class="pe-critic-linenumber [% x=v.line_number; todos.$x %]">[% v.line_number %]</td>
          <td>[% v.column_number %]</td>
          <td class="severity">[% v.severity %]</td>
          <td class="pe-critic-policy">[% v.policy_short %]</td>
          <td class="pe-critic-source[% IF v.source %] tooltip[% END %]">[% v.source_snippet %][% IF v.source %]<span class="tooltip-text">[% v.source %][% END %]</span></td>
          <td class="pe-critic-description[% IF v.description %] tooltip[% END %]">[% v.description_snippet %][% IF v.description %]<span class="tooltip-text">[% v.description %]</span>[% END %]</td>
        </tr>
      [% END -%]
      </tbody>
    </table>
    <div id="tooltip-container"></div>
  </body>
</html>

=pod


=cut
