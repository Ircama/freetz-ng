package File::Basename;

use strict;
use warnings;
use Exporter 'import';

our $VERSION = '2.86';

our @EXPORT_OK = qw(basename dirname fileparse);

sub basename {
    my $path = shift;
    my $suffix = shift;
    
    $path =~ s|.*[/\\]||;
    if (defined $suffix && $suffix ne '') {
        $path =~ s/\Q$suffix\E$//;
    }
    return $path;
}

sub dirname {
    my $path = shift;
    
    return '.' if $path !~ m|[/\\]|;
    
    $path =~ s|[/\\][^/\\]*$||;
    return $path || '.';
}

sub fileparse {
    my ($fullname, $suffix) = @_;
    
    my $dirname = dirname($fullname);
    my $basename = basename($fullname, $suffix);
    
    return ($basename, $dirname, $suffix);
}

1;