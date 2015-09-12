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
    $self->{iter}        = [ {} ];
    $self->{parse_target} = $self->{iter}->[0];
    $self->{debug}       = $opts{debug};
    $self->{source_tag_width} = (defined $opts{source_tag_width} ? $opts{source_tag_width} : 20);

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
    print sdump($self->{iter});
}

sub parse_line {
    my ($self,$line) = @_;
    chomp $line;
    my $line_time;
    $line_time = $1 if ($line =~ s/^\s*(\d+\.\d+)\s*\| //);
    push @{$self->{line_time}},$line_time;
    push @{$self->{line}}     ,$line;
    my ($parser_source,$parser_line) = $self->_parse_line($line,$#{$self->{line}});
    if ($self->{debug}) {
        my $debug_output='';
        if (defined $parser_source) {
            $parser_source=$1 if ($parser_source=~/(OUT.*)$/);
            $parser_source=substr($parser_source,-$self->{source_tag_width})
                if (length($parser_source)>$self->{source_tag_width});
            $debug_output.=sprintf("%" . $self->{source_tag_width} . "s:%04d | ",$parser_source,$parser_line);
        } else {
            $debug_output.=sprintf("%" . ($self->{source_tag_width}+5) . "s | ",'unparsed');
        }
        $debug_output.=sprintf("%20.3f | ",$line_time) if (defined $line_time);
        print STDERR $debug_output . $line . "\n";
    }
}

sub _parse_line {
    my ($self,$line,$lineno) = @_;
    my $dest=$self->{parse_target};
    if ($line=~/^\s*Program\s+(.*)\s+v(\S+)\s+starts on\s+(\S+)\s+at\s+(\S+)\s*$/) {
        $dest->{prog_name}=$1;
        $dest->{prog_version}=$2;
        $dest->{start_date}=$3;
        $dest->{start_time}=$4;
        return(__FILE__,__LINE__);
    } elsif ($line=~/^\s*git_version:\s*(\S+):\s*(.*?)\s*$/) {
        $dest->{$1}=$2;
        return(__FILE__,__LINE__);
    }
    return(undef);
}

1;
