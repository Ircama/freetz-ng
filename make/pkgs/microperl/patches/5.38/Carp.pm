package Carp;

use strict;
use warnings;

our $VERSION = '1.52';

our @EXPORT = qw(carp croak confess cluck);

sub carp {
    warn @_, "\n";
}

sub croak {
    die @_, "\n";
}

sub confess {
    die @_, "\n";
}

sub cluck {
    warn @_, "\n";
}

1;