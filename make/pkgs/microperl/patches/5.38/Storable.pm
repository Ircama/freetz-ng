package Storable;
our $VERSION = '3.25';

# Stub implementation for microperl

use Exporter 'import';
our @EXPORT_OK = qw(dclone);

sub dclone {
    my $obj = shift;
    return $obj;  # Stub: return as is
}

1;
