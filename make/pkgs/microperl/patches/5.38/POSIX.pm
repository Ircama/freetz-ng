package POSIX;
our $VERSION = '2.13';

# Stub implementation for microperl
# Only implement the functions needed by Autom4te

sub WIFEXITED {
    my $status = shift;
    return ($status & 0xFF) == 0;
}

sub WEXITSTATUS {
    my $status = shift;
    return ($status >> 8) & 0xFF;
}

sub WIFSIGNALED {
    my $status = shift;
    return ($status & 0xFF) != 0;
}

sub WTERMSIG {
    my $status = shift;
    return $status & 0x7F;
}

# Export them
use Exporter 'import';
our @EXPORT_OK = qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG);

1;
