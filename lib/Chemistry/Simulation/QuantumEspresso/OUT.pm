package Chemistry::Simulation::QuantumEspresso::OUT;
use strict;
use warnings;
use Carp;
use PDL;
use PDL::IO::Dumper;

sub new {
    my $class = shift;
    my $self  = {};
    bless($self,$class);
    return($self->init(@_));
}

sub init {
    my $self=shift;
    my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'HASH'));

    $self->{line}        = []; # line contents
    $self->{line_time}   = []; # line timestamp, defined if applicable
    $self->{parse_target} = $self;
    $self->{debug}       = $opts{debug};

    # read in initial data
    my @init_lines;
    if (defined $opts{data}) {
        @init_lines = split /\n/,$opts{data};
    } elsif (defined $opts{filename}) {
        $self->{filename} = $opts{filename};
        # slurp in file
        if (open(my $fh,$opts{filename})) {
            chomp (@init_lines = <$fh>);
        } else {
            carp "Error opening file '$opts{filename}'";
            return(undef);
        }
    }
    foreach my $line (@init_lines) {
        $self->parse_line($line);
    }
}

sub parse_line {
    my ($self,$line) = @_;
    chomp $line;
    my $line_time=0.0;
    $line_time =$1 if ($line =~ s/^\s*(\d+\.\d+)\s*\| //);
    push @{$self->{line_time}},$line_time;
    push @{$self->{line}}     ,$line;
    my $parsed = $self->_parse_line($line,$#{$self->{line}});
    if ($self->{debug}) {
        my $line_parsed=(defined $parsed ? $parsed : 'unparsed');
        printf STDERR "%-20s | %20.3f | %s\n",$line_parsed,$line_time,$line;
    }
}

sub _parse_line {
    my ($self,$line,$lineno) = @_;
    return(__FILE__ . ":" . __LINE__) if ($line=~/^\s+$/);
    return(undef);
}

1;
