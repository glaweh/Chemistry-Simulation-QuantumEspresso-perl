package Chemistry::Simulation::QuantumEspressoProjwfc;
# Parser for Quantum Espresso's projwfc.x output
# Copyright (C) 2010 Henning Glawe <glaweh@debian.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;
use PDL;
use PDL::NiceSlice;

my $version=1.0;

sub parse {
	use Fcntl ":seek";
	use PDL::IO::Dumper;
	my $fname=shift;
	my $user_opt=shift;
	my $cachefile="$fname.cache.pdld";
	my $options={
		DEBUG=>0,
		CACHE=>1
	};
	if (defined $user_opt) {
		foreach (keys %{$user_opt}) {
			$options->{$_}=$user_opt->{$_};
		}
	}

	my $fh;
	if (($options->{CACHE}>0) and (-r $cachefile)) {
		my $cached_data=frestore($cachefile);
		if ($cached_data->{version}==$version) {
			$cached_data->{cached}=1;
			print STDERR "Read from cachefile $cachefile\n" if ($options->{DEBUG}>0);
			return($cached_data);
		}
	}

	my $data={
		version=>$version
	};

	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}
	$data->{SOURCEFILE}=$fname;

	my $nktot=0;
	my $nbnd=0;
	my $nstates=0;

	# first count stuff for later static allocation...
	while (<$fh>) {
		chomp;
		$nstates++ if (/^\s+state #/);
		$nktot++   if (/^\s+k\s+=\s+/);
		# count bands on first kpoint
		$nbnd++    if (($nktot==1) and (/^\s+e\s+=\s+/));
	}

	# allocate piddles
	my ($kvec,$projbnd,$psi2,$projstates,$ebnd);
	$kvec       = $data->{kvec}       = zeroes(3,$nktot);
	$ebnd       = $data->{ebnd}     = zeroes($nbnd,$nktot);
	$projbnd    = $data->{projbnd}    = zeroes($nstates,$nbnd,$nktot);
	$psi2       = $data->{psi2}       = zeroes($nbnd,$nktot);
	$projstates = $data->{projstates} = zeroes(long,4,$nstates);

	if (! seek($fh,0,SEEK_SET)) {
		print "couldn't rewind file $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}

	# now do the real parse run
	my $nk=0;
	while (<$fh>) {
		chomp;
		if (/state #\s*(\d+): atom\s*(\d+)\s*\(\s*(\S+)\s*\), wfc\s*(\d+)\s*\(l=\s*(\d+)\s*m=\s*(\d+)\s*\)/) {
			$data->{atoms}->[$2-1]=$3;
			$projstates(:,$1-1) .= pdl(long,$2-1,$4-1,$5,$6);
			next;
		}
		if (/^Lowdin Charges/) {
			$data->{lowdin}= parse_lowdin($fh,$options);
			next;
		}
		if (/^\s*k\s*=\s*([0-9\.-]+)\s+([0-9\.-]+)\s+([0-9\.-]+)\s*$/) {
			$kvec(:,$nk;-).=pdl($1,$2,$3);
			print STDERR "found k $nk: " . $kvec(:,$nk;-) . "\n" if ($options->{DEBUG} > 1);
			parse_band_projection($fh,$options,
				$ebnd(:,$nk;-),
				$projbnd(:,:,$nk;-),
				$psi2(:,$nk;-)
			);
			$nk++;
		}
		print STDERR 'parse_pw_out unparsed: ' . $_ . "\n" if ($options->{DEBUG} > 2);
	}
	close($fh);
	if ($options->{CACHE}>0) {
		if (fdump($data,$cachefile)) {
			print STDERR "Written to cachefile $cachefile\n" if ($options->{DEBUG}>0);
		}
	}

	return($data);
}

sub parse_lowdin {
	my $fh=shift;
	my $options=shift;
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
				$result->{atoms}->[$atom-1]->{$type}->{$1}=$2 if (/(\S+)\s*=\s*(\S+)/);
			}
		}

	}
	return($result);
}

sub parse_band_projection {
	my ($fh,$options,$ebnd_k,$projbnd_k,$psi2_k) = @_;
	my $nbnd=0;
	while (<$fh>) {
		chomp;
		last if (/^\s*$/);
		if (/\s*e\s*=\s*([0-9\.-]+)\s*eV/) {
			$ebnd_k($nbnd).=$1;
			print STDERR "e=$1\n" if ($options->{DEBUG}>2);
			next;
		}
		if (/\|psi\|\^2\s*=\s*([0-9\.-]+)/) {
			$psi2_k($nbnd).=$1;
			$nbnd++;
			next;
		}
		#pattern:
		# 0.476*[#  29]
		while (/([0-9.-]+)\*\[#\s*(\d+)\]/g) {
			$projbnd_k($2-1,$nbnd).=$1;
		}
	}
	return 1;
}

1;
