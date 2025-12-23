package constant;

use strict;
use warnings;

our $VERSION = '1.33';

sub import {
    my $class = shift;
    my $name = shift;
    my $value = shift;
    
    # Simple constant definition
    no strict 'refs';
    *{$name} = sub () { $value };
}

1;