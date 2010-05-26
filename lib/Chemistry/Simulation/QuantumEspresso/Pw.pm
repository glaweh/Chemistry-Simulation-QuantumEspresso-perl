package Chemistry::Simulation::QuantumEspressoPw;
use strict;
use warnings;
use PDL;
use PDL::NiceSlice;

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
	my $iter=0;
	my $end_of_scf=0;
	my $ik=0;

	my $fh;

	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}

	while (<$fh>) {
		chomp;
		if (/iteration #\s*(\d+)\s*ecut=\s*(\S+)\s*Ry\s*beta=\s*(\S+)/) {
			$iter=$1;
			$data[$iter]->{ecut}=$2;
			$data[$iter]->{beta}=$3;
			$ik=0;
			next;
		}
		if (/     End of self-consistent calculation/) {
			$end_of_scf=1;
			next;
		}
		if (/ enter write_ns/) {
			$data[$iter]->{hubbard}= parse_write_ns($fh);
			next;
		}
		if (/^!?\s*total energy\s*=\s*(\S+)\s*Ry$/) {
			$data[$iter]->{E_total}=$1;
			next;
		}
		if (/^\s*total magnetization\s*=\s*(\S+)\s*Bohr mag\/cell$/) {
			$data[$iter]->{m_total}=$1;
			next;
		}
		if (/^\s*absolute magnetization\s*=\s*(\S+)\s*Bohr mag\/cell$/) {
			$data[$iter]->{m_absolute}=$1;
			next;
		}
		if (/^\s*total cpu time spent up to now is\s*(\S+)\s*secs$/) {
			$data[$iter]->{t_cpu}=$1;
			next;
		}
		if (/^\s*the Fermi energy is\s*(\S+)\s*ev$/) {
			$data[$iter]->{E_Fermi}=$1;
			next;
		}
		if (/^\s*ethr =\s*(\S+),/) {
			$data[$iter]->{ethr}=$1;
			next;
		}
		if (/^\s*number of k points=\s*(\d+)/) {
			$data[$iter]->{nk}=$1;
			next;
		}
		if (/^\s*number of Kohn-Sham states=\s*(\d+)/) {
			$data[$iter]->{nbnd}=$1;
			next;
		}
		if (/^\s*Program PWSCF v.(\S+)/) {
			$data[$iter]->{version_string}=$1;
			my @vers=split(/\./,$1);
			my $vers_multiplier=1000000;
			my $vers_num=0;
			foreach my $v_part (@vers) {
				$v_part=~/^(\d+)/;
				$vers_num+=$vers_multiplier*$1;
				$vers_multiplier/=1000;
			}
			$data[$iter]->{version}=$vers_num;
			next;
		}
		if (/^\s*k =.* bands \(ev\):/) {
			$data[$iter]->{bands}=parse_bands($fh,$data[0]->{nk},$data[0]->{nbnd},$_,$options);
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
				$atoms[$1]->{U}=$2;
			}
			next;
		}
		if (/^alpha\(/) {
			while (/alpha\(\s*(\d+)\)\s*=\s*(\d+\.\d+)/g) {
				$atoms[$1]->{alpha}=$2;
			}
			next;
		}
		if (/^atom\s*(\d+)\s*Tr\[ns\(na\)\]=\s*(\d+\.\d+)/) {
			$in_occupations=0;
			$atoms[$1]->{Trns}=$2;
			next;
		}
		if (/^atom\s*(\d+)\s*spin\s*(\d+)/) {
			$atom=$1;
			$spin=$2;
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

sub parse_bands {
	my $fh=shift;
	my $nk=shift;
	my $nbnd=shift;
	$_ = shift;
	my $options=shift;
	my $result;
	my $ik=-1;
	my @accum;
	my $hot=0;
	$result->{kvec}=zeroes(3,$nk);
	$result->{npw}=zeroes(long,$nk);
	$result->{ebnd}=zeroes($nbnd,$nk);
	LINE: { do {{
		chomp;
		# insert spaces in front of minus signs to work around broken pw format strings
		s/-/ -/g;
		if ($hot and /^\s*$/) {
			if ($options->{DEBUG}>2) {
				print STDERR "$ik/$nk: $#accum\n";
				print STDERR join(" ",@accum) . "\n";
			}
			$result->{ebnd}->(:,$ik;-).=pdl(@accum);
			@accum=();
			$hot=0;
			last LINE if ($ik==$nk-1);
		}
		if (/^\s*k =\s*(.*) \(\s*(\d+) PWs\)   bands \(ev\):\s*$/) {
			$ik++;
			$result->{npw}->($ik).=$2;
			$result->{kvec}->(:,$ik;-).=pdl(split /\s+/,$1);
			$_=<$fh>;
			$hot=1;
			next;
		}
		push @accum,split if ($hot);
	}} while (<$fh>) };
	return $result;
}

1;
