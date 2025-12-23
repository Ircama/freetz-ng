package feature;

use strict;
use warnings;

our $VERSION = '1.82';

# Stub implementation for feature.pm
# Most features are not available in microperl

sub import {
    my $class = shift;
    # Ignore feature requests in microperl
}

sub unimport {
    my $class = shift;
    # Ignore feature unimport in microperl
}

1;