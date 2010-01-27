package Chemistry::Simulation::QuantumEspressoPw;
use strict;
use warnings;

BEGIN {
	use Exporter ();
	our (@EXPORT,@ISA);
	@ISA=qw(Exporter);
	@EXPORT=qw(&parse_pw_out);
}

sub parse_pw_out {
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

	my @data;
	my $in_write_ns=0;
	my $iter=0;

	my $fh;

	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}

	while (<$fh>) {
		chomp;
		if (/iteration #\s*(\d+)\s*ecut=\s*(\d+\.\d+)\s*Ry\s*beta=\s*(\d+\.\d+)/) {
			$iter=$1+1;
			$data[$iter]->{ecut}=$2;
			$data[$iter]->{beta}=$3;
			next;
		}
		if (/     End of self-consistent calculation/) {
			$iter=1;
			next;
		}
		if (/ enter write_ns/) {
			$data[$iter]->{hubbard}=parse_write_ns($fh);
			next;
		}
		if (/^!?\s*total energy\s*=\s*(-?\d+.\d+) Ry$/) {
			$data[$iter]->{E_total}=$1;
			next;
		}
		if (/^\s*total magnetization\s*=\s*(-?\d+.\d+) Bohr mag\/cell$/) {
			$data[$iter]->{m_total}=$1;
			next;
		}
		if (/^\s*absolute magnetization\s*=\s*(-?\d+.\d+) Bohr mag\/cell$/) {
			$data[$iter]->{m_absolute}=$1;
			next;
		}
		if (/^\s*total cpu time spent up to now is\s*(\d+\.\d+)\s*secs$/) {
			$data[$iter]->{t_cpu}=$1;
			next;
		}
		if (/^\s*the Fermi energy is\s*(\d+\.\d+)\s*ev$/) {
			$data[$iter]->{E_Fermi}=$1;
			next;
		}
		print STDERR 'parse_pw_out unparsed: ' . $_ . "\n" if ($options->{DEBUG} > 2);
	}
	close($fh);
	return(\@data);
}

sub parse_write_ns {
	my $fh=shift;
	my $options=shift;
	my ($atom,$spin);
	my $result;
	my @atoms;
	my $in_occupations;
	my $in_eigenvectors;
	$in_occupations=$in_eigenvectors=0;
	$atom=$spin=0;
	while (<$fh>) {
		chomp;
		last if (/^ exit write_ns/);
		if (/^U\(/) {
			while (/U\(\s*(\d+)\)\s*=\s*(\d+\.\d+)/g) {
				$atoms[$1-1]->{U}=$2;
			}
			next;
		}
		if (/^alpha\(/) {
			while (/alpha\(\s*(\d+)\)\s*=\s*(\d+\.\d+)/g) {
				$atoms[$1-1]->{alpha}=$2;
			}
			next;
		}
		if (/^atom\s*(\d+)\s*Tr\[ns\(na\)\]=\s*(\d+\.\d+)/) {
			$in_occupations=0;
			$atoms[$1-1]->{Trns}=$2;
			next;
		}
		if (/^atom\s*(\d+)\s*spin\s*(\d+)/) {
			$atom=$1-1;
			$spin=$2-1;
			next;
		}
		if (s/^eigenvalues:\s*//) {
			@{$atoms[$atom]->{spin}->[$spin]->{eigenvalues}}=split;
			next;
		}
		if (/^ occupations/) {
			$in_occupations=1;
			$in_eigenvectors=0;
			next;
		}
		if (/^ eigenvectors/) {
			$in_eigenvectors=1;
			next;
		}
		if (/^nsum\s*=\s*(\d+\.\d+)/) {
			$in_occupations=0;
			$result->{nsum}=$1;
			next;
		}
		if ($in_eigenvectors) {
			my ($idx,@vec)=split;
			@{$atoms[$atom]->{spin}->[$spin]->{eigenvectors}->[$idx-1]}=@vec;
			next;
		}
		if ($in_occupations) {
			my (@line)=split;
			push @{$atoms[$atom]->{spin}->[$spin]->{occupations}},\@line;
			next;
		}
		print STDERR 'parse_write_ns unparsed: ' . $_ . "\n" if ($options->{DEBUG} > 2);
	}
	$result->{atoms}=\@atoms;
	return($result);
}

1;
