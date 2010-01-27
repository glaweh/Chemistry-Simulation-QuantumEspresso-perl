package Chemistry::Simulation::QuantumEspressoProjwfc;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	our (@EXPORT,@ISA);
	@ISA=qw(Exporter);
	@EXPORT=qw(&parse_projwfc_out);
}

sub parse_projwfc_out {
	my $fname=shift;
	my $user_opt=shift;
	my $options={
		DEBUG=>0
	};
	if (defined $user_opt) {
		foreach (keys %{$user_opt}) {
			$options->{$_}=$user_opt->{$_};
		}
	}

	my $data={};
	my $fh;

	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}

	while (<$fh>) {
		chomp;
		if (/^Lowdin Charges/) {
			$data->{lowdin}= parse_lowdin($fh);
			next;
		}
		print STDERR 'parse_pw_out unparsed: ' . $_ . "\n" if ($options->{DEBUG} > 2);
	}
	close($fh);
	return($data);
}
sub parse_lowdin {
	my $fh=shift;
	my $result;
	my $atom=0;
	while (<$fh>) {
		chomp;
		s/^\s*//;
		if (/Spilling Parameter:\s*(\S+)/) {
			$result->{spilling}=$1;
			last;
		}
		if (s/Atom #\s*(\d+): total charge/total/) {
			$atom=$1;
		}
		s/^spin\s*//;
		if (s/^(\S+)/sum/) {
			my $type=$1;
			foreach (split(/\s*,\s*/,$_)) {
				$result->{atoms}->[$atom]->{$type}->{$1}=$2 if (/(\S+)\s*=\s*(\S+)/);
			}
		}

	}
	return($result);
}

1;
