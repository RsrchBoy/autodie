package autodie::hints;

use strict;
use warnings;

=head1 NAME

autodie::hints - Provide hints about user subroutines to autodie

=cut

# This file contains hints on how user-defined subroutines should
# be handled.  For scalar context, there are two options:

use constant SCALAR_ANY_FALSE   => 0;   # Default
use constant SCALAR_UNDEF_ONLY  => 1;

# For list context, there are more options:

use constant LIST_EMPTY_OR_UNDEF => 0;  # Default
use constant LIST_EMPTY_ONLY     => 2;
use constant LIST_EMPTY_OR_FALSE => 4;

use constant DEFAULT_HINTS => 0;

use constant MAX_HINT_VALUE =>
    SCALAR_UNDEF_ONLY | LIST_EMPTY_ONLY | LIST_EMPTY_OR_FALSE;

use base qw(Exporter);

our @EXPORT_OK = qw(
    SCALAR_ANY_FALSE SCALAR_UNDEF_ONLY
    LIST_EMPTY_OR_FALSE LIST_EMPTY_ONLY LIST_EMPTY_OR_UNDEF
    DEFAULT_HINTS
);

our $DEBUG = 0;

# Only ( undef ) is a strange but possible situation for very
# badly written code.  It's not supported yet.

# TODO: Should we allow 'File::Copy::*' as a hash key?  This
# would be useful for modules which have lots of subs which
# express the same interface.

my %hints = (
    'File::Copy::copy' => LIST_EMPTY_OR_FALSE,
    'File::Copy::move' => LIST_EMPTY_OR_FALSE,
);

# Start by using Sub::Identify if it exists on this system.

eval { require "Sub::Identify"; Sub::Identify->import('get_code_info'); };

# If it doesn't exist, we'll define our own.  This code is directly
# taken from Rafael Garcia's Sub::Identify 0.04, used under the same
# license as Perl itself.

if ($@) {
    require B;

    no warnings 'once';

    *get_code_info = sub ($) {

        my ($coderef) = @_;
        ref $coderef or return;
        my $cv = B::svref_2object($coderef);
        $cv->isa('B::CV') or return;
        # bail out if GV is undefined
        $cv->GV->isa('B::SPECIAL') and return;

        return ($cv->GV->STASH->NAME, $cv->GV->NAME);
    };

}

sub sub_fullname {
    return join( '::', get_code_info( $_[1] ) );
}

sub get_hints_for {
    my ($class, $sub) = @_;

    my $subname = $class->sub_fullname( $sub );

    my $hints = $hints{ $subname };

    if ($DEBUG) {
        warn "autodie::hints: Got hints for $subname: $hints\n";
    }

    return defined($hints) ? $hints : DEFAULT_HINTS;

}

sub set_hints_for {
    my ($class, $sub, $hints) = @_;

    if (ref $sub) {
        $sub = $class->sub_fullname( $sub );

        require Carp;

        $sub or Carp::croak("Attempts to set_hints_for unidentifiable subroutine");
    }

    # TODO - I'm unhappy with our hints processing.  The user feedback is
    # awful (they're numeric), and people need to understand bitwise
    # ops to set them.  We're *much* better off using human-friendly
    # strings/tokens, and converting them to bitstrings internally if
    # needed.

    if ($hints < 0 or $hints > MAX_HINT_VALUE) {
        require Carp;

        Carp::croak("Invalid hint '$hints' passed to set_hints_for");
    }

    if ($DEBUG) {
        warn "autodie::hints: Setting $sub to hints: $hints\n";
    }

    $hints{ $sub } = $hints;

    return;
}

1;

__END__

=head1 Diagnostics

=head2 Attempts to set_hints_for unidentifiable subroutine

You've called C<autodie::hints->set_hints_for()> using a subroutine
reference, but that reference could not be resolved back to a
subroutine name.  It may be an anonymous subroutine (which can't
be made autodying), or may lack a name for other reasons.

If you receive this error with a subroutine that has a real name,
then you may have found a bug in autodie.  See L<autodie/BUGS>
for how to report this.

=head1 AUTHOR

Copyright 2009, Paul Fenwick E<lt>pjf@perltraining.com.auE<gt>

=head1 LICENSE

This module is free software.  You may distribute it under the
same terms as Perl itself.

=head1 SEE ALSO

L<autodie>

=cut
