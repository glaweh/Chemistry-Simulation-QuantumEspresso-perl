package Chemistry::Simulation::QuantumEspresso::pp::out;
# Parser for pp.x
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
		if ((ref $cached_data eq 'HASH') and (defined $cached_data->{version}) and ($cached_data->{version}==$version)) {
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
		if (/^\s*Gaussian broadening \((.*)\): ngauss,degauss=\s*(\S+)\s+(\S+)/) {
			$data->{gaussian}->{reason}=$1;
			$data->{gaussian}->{ngauss}=$2;
			$data->{gaussian}->{degauss}=$3;
		}
		if (/^\s*Tetrahedra used/) {
			$data->{tetrahedra}=1;
		}
	}

	close($fh);
	if ($options->{CACHE}>0) {
		if (fdump($data,$cachefile)) {
			print STDERR "Written to cachefile $cachefile\n" if ($options->{DEBUG}>0);
		}
	}

	return($data);
}

1;
