package Chemistry::Simulation::QuantumEspresso::projwfc::out;
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
use Storable;
use PDL::IO::Storable;

my $version=1.0;

sub parse {
	use Fcntl ":seek";
	my $fname=shift;
	my $user_opt=shift;
	my $cachefile="$fname.cache.storable";
	my $options={
		DEBUG=>0,
		CACHE=>1,
		PARSE_K_PROJ=>1,
	};
	if (defined $user_opt) {
		foreach (keys %{$user_opt}) {
			$options->{$_}=$user_opt->{$_};
		}
	}

	my $fh;
	if (($options->{CACHE}>0) and (-r $cachefile)) {
		my $cached_data=retrieve($cachefile);
		if ((ref $cached_data eq 'HASH') and (defined $cached_data->{version}) and ($cached_data->{version}==$version)) {
			$cached_data->{cached}=1;
			print STDERR "Read from cachefile $cachefile\n" if ($options->{DEBUG}>0);
			return($cached_data);
		}
	}

	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{DEBUG}>0);
		return(undef);
	}
	my @lines=<$fh>;
	close($fh);

	my $i=0;
	my (@atoms,$projstates);
	do {
		my @projstates;
		while ($i<=$#lines) {
			$_=$lines[$i++];
			last if (($#atoms>=0) and /^\s*$/);
			if (/^\s*state #\s*(\d+): atom\s*(\d+)\s*\(\s*(\S+)\s*\), wfc\s*(\d+)\s*\(l=\s*(\d+)\s*m=\s*(\d+)\s*\)/) {
				$atoms[$2-1]=$3;
				push @projstates,[ $2-1, $4-1, $5, $6 ];
			}
		}
		$projstates=pdl(long,\@projstates);
	};
	my ($kvec,$proj,$psi2,$ebnd);
	if ($options->{PARSE_K_PROJ}) {
		my (@kvec,@proj,@psi2,@ebnd);
		while ($i<=$#lines) {
			$_=$lines[$i++];
			last if (/^\s*Lowdin Charges:/);
			if (my @kvec_i=/^\s+k\s+=\s+(\S+)\s+(\S+)\s+(\S+)/) {
				push @kvec, pdl(\@kvec_i);
				my (@ebnd_k,@psi2_k,@idx_k,@proj_k);
				while ($i<=$#lines) {
					$_=$lines[$i++];
					last if (/^\s*$/);
					if (/^=+\s+e(?:\(\s*\d+\))?\s*=\s+(\S+)/) {
						push @ebnd_k,$1;
						my   $n_i=$#ebnd_k;
						my   @psi2_k_n;
						push @psi2_k,\@psi2_k_n;
						while ($i<=$#lines) {
							$_=$lines[$i++];
							if (/^\s+\|psi\|\^2\s+=\s+(\S+)/) {
								push @psi2_k_n, $1;
								last;
							}
							while (/(\d+\.\d+)\*\[#\s*(\d+)\]/g) {
								push @idx_k,  [ $2-1, $n_i ];
								push @proj_k, $1;
							}
						}
					}
				}
				push @ebnd,pdl(\@ebnd_k);
				push @psi2,pdl(\@psi2_k);
				my $proj_k=zeroes($projstates->dim(1),$#ebnd_k+1);
				$proj_k->indexND(pdl(long,\@idx_k)).=pdl(\@proj_k);
				push @proj,$proj_k;
			}
		}
		$kvec=pdl(\@kvec);
		$proj=pdl(\@proj);
		$psi2=pdl(\@psi2);
		$ebnd=pdl(\@ebnd);
	} else {
		while ($i<=$#lines) {
			$_=$lines[$i++];
			last if (/^\s*Lowdin Charges:/);
		}
	}
	my $data = {
		lowdin     => parse_lowdin(\@lines,\$i,$options),
		kvec       => $kvec,
		ebnd       => $ebnd,
		projbnd    => $proj,
		psi2       => $psi2,
		projstates => $projstates,
		atoms      => \@atoms,
		version    => $version,
		SOURCEFILE => $fname,
	};

	if ($options->{CACHE}>0 and $options->{PARSE_K_PROJ}) {
		if (store($data,$cachefile)) {
			print STDERR "Written to cachefile $cachefile\n" if ($options->{DEBUG}>0);
		}
	}

	return($data);
}

sub parse_lowdin {
	my $lines=shift;
	my $ir   =shift;
	my $options=shift;
	my $result;
	my $atom=0;
	while (${$ir} <= $#{$lines}) {
		$_=$lines->[${$ir}++];
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

1;
