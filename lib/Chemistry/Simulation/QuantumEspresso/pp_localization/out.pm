package Chemistry::Simulation::QuantumEspresso::pp_localization::out;
# Parser for our patched pp_localization.x
# Copyright (C) 2011 Henning Glawe <glaweh@debian.org>
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

my $version=1.1;

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

	my $hot = 0;
	my (@e_from,@e_to,@n_pnts,@loc_param,@dos,@atomic_loc_dos);
	while (<$fh>) {
		chomp;
		if (/^\s*from (\S+)\s*:\s*error\s*#\s*(\d+)/) {
			my ($err_name,$err_num)=($1,$2);
			my @err_msg;
			while (<$fh>) {
				chomp;
				last if (/%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%/);
				s/^\s*//;
				s/\s*$//;
				push @err_msg,$_;
			}
			$data->{error}->{$err_name}->[0]=$err_num;
			$data->{error}->{$err_name}->[1]=join("\n",@err_msg);
			next;
		}
		$hot = 0 if ($hot and /^\s+-{2,}/);
		if ($hot) {
			if (/^\s*(\S+)\s+(\S+)\s*\|\s*(\S+)\s*\|\s*(\S+)\s+(\S+)/) {
				push @e_from   ,$1;
				push @e_to     ,$2;
				push @n_pnts   ,$3;
				push @loc_param,$4;
				push @dos      ,$5;
				push @atomic_loc_dos,[];
			} elsif (/^\s*Atomic\s+loc_dos\s+(\d+)\s+([+-]?(?:\d*\.\d+|\d+)(?:[eE][+-]?\d+)?)/) {
				$atomic_loc_dos[-1]->[$1-1]=$2;
			}
		}
		$hot = 1 if (/^ene:\s+from\s+to/);
	}
	$data->{e_from}    = pdl(\@e_from);
	$data->{e_to}      = pdl(\@e_to);
	$data->{n_pnts}    = pdl(long,\@n_pnts);
	$data->{loc_param} = pdl(\@loc_param);
	$data->{dos}       = pdl(\@dos);
	$data->{atomic_loc_dos} = pdl(\@atomic_loc_dos);

	close($fh);
	if ($options->{CACHE}>0) {
		if (fdump($data,$cachefile)) {
			print STDERR "Written to cachefile $cachefile\n" if ($options->{DEBUG}>0);
		}
	}

	return($data);
}

1;
