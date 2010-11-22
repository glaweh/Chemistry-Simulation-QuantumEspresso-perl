package Chemistry::Simulation::QuantumEspressoPw;
use strict;
use warnings;
use PDL;
use PDL::IO::Dumper;
use PDL::NiceSlice;

BEGIN {
	use Exporter ();
	our (@EXPORT,@ISA);
	@ISA=qw(Exporter);
	@EXPORT=qw(&parse_pw_out);
}
my $parser_version_major=1;
my $parser_version_minor=5;

sub annotate_debug($$$$) {
	my ($fh,$sub,$parsed,$data)=@_;
	printf $fh '%14s::$_::%8s::%05d::%s',$sub,($parsed ? 'parsed' : 'unparsed'),$parsed,$data;
}

sub parse_pw_out {
	my $fname=shift;
	my $user_opt=shift;
	my $cachefile="$fname.cache.$parser_version_major.pdld";
	my $options={
		DEBUG_UNPARSED=>0,
		DEBUG_BANDS_ACCUM=>0,
		ANNOTATED_DEBUG_FILE=>'',
		VERBOSE=>0,
		CACHE=>1
	};
	if (defined $user_opt) {
		foreach (keys %{$user_opt}) {
			$options->{$_}=$user_opt->{$_};
		}
	}

	if (($options->{CACHE}>0) and (-s $cachefile)) {
		my $cached_data=frestore($cachefile);
		if ($cached_data->[0]->{parser_version_minor}==$parser_version_minor) {
			$cached_data->[0]->{parser_cached}=1;
			print STDERR "Read from cachefile $cachefile\n" if ($options->{VERBOSE}>0);
			return($cached_data);
		}
	}
	if ($options->{ANNOTATED_DEBUG_FILE} and (exists $options->{ANNOTATED_DEBUG_FH})) {
		print STDERR "options ANNOTATED_DEBUG_FILE and ANNOTATED_DEBUG_FH are mutually exclusive\n";
		return(undef);
	}
	my $annotated_debug_fh;
	if ($options->{ANNOTATED_DEBUG_FILE}) {
		if (! open($annotated_debug_fh,'>',$options->{ANNOTATED_DEBUG_FILE})) {
			print "couldn't open annotated debug file $options->{ANNOTATED_DEBUG_FILE}\n" if ($options->{VERBOSE}>0);
			return(undef);
		}
		$options->{ANNOTATED_DEBUG_FH}=$annotated_debug_fh;
	}

	my @data;
	my $iter=0;
	my $ik=0;

	my $fh;

	$data[0]->{parser_version_major}=$parser_version_major;
	$data[0]->{parser_version_minor}=$parser_version_minor;
	if (! open($fh,$fname)) {
		print "couldn't open $fname\n" if ($options->{VERBOSE}>0);
		return(undef);
	}

	my $fh_line;
	my $fh_parsed;
	while (<$fh>) {
		$fh_line=$_;
		chomp;
		$fh_parsed=0;
		if (/^\s*$/) {
			$fh_parsed=__LINE__-1;
			next;
		}
		if (/iteration #\s*(\d+)\s*ecut=\s*(\S+)\s*Ry\s*beta=\s*(\S+)/) {
			$fh_parsed=__LINE__-1;
			$iter++;
			$data[$iter]->{iteration}=$1;
			$data[$iter]->{ecut}=$2;
			$data[$iter]->{beta}=$3;
			$ik=0;
			next;
		}
		if (/     End of self-consistent calculation/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{end_of_scf}=1;
			next;
		}
		if (/End of band structure calculation/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{end_of_nscf}=1;
			next;
		}
		if (/^\s*convergence NOT achieved after (\d+) iterations: stopping\s*/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{convergence_not_achieved}=$1;
			next;
		}
		if (/^\s*convergence has been achieved in\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{convergence_achieved}=$1;
			next;
		}
		if (/^\s*Starting wfc from file/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{starting_wfc}='file';
			next;
		}
		if (/^\s*Starting wfc are.*atomic wfcs/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{starting_wfc}='atomic';
			next;
		}
		if (/The initial density is read from file/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{starting_potential}='file';
			next;
		}
		if (/Initial potential from superposition of free atoms/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{starting_potential}='atomic';
			next;
		}
		if (/NEW-OLD atomic charge density approx\. for the potential/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{starting_potential}='new_old_atomic';
			next;
		}
		if (/ enter write_ns/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$fh_line='';
			$data[$iter]->{hubbard}= parse_write_ns($fh,$options);
			next;
		}
		if (/^!?\s*total energy\s*=\s*(\S+)\s*Ry$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{E_total}=$1;
			next;
		}
		if (/^\s*total magnetization\s*=\s*(\S+)\s*Bohr mag\/cell$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{m_total}=$1;
			next;
		}
		if (/^\s*absolute magnetization\s*=\s*(\S+)\s*Bohr mag\/cell$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{m_absolute}=$1;
			next;
		}
		if (/^\s*total cpu time spent up to now is\s*(\S+)\s*secs$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{t_cpu}=$1;
			next;
		}
		if (/^\s*the Fermi energy is\s*(\S+)\s*ev$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{E_Fermi}=$1;
			next;
		}
		if (/^\s*ethr =\s*(\S+),/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{ethr}=$1;
			next;
		}
		if (/^\s*number of k points=\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{nk}=$1;
			next;
		}
		if (/^\s*number of atoms\/cell\s*=\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{nat}=$1;
			next;
		}
		if (/^\s*number of atomic types\s*=\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{ntyp}=$1;
			next;
		}
		if (/^\s*number of Kohn-Sham states=\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{nbnd}=$1;
			next;
		}
		if (/^\s*number of electrons\s*=\s*([0-9\.]+)/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{nelec}=$1;
		}
		## BEGIN stuff found in version 3.2
		if (/^\s*nbndx\s*=\s*(\d+)\s*nbnd\s*=\s*(\d+)\s*natomwfc\s*=\s*(\d+)\s*npwx\s*=\s*(\d+)\s*$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{_nbndx}=$1;
			$data[$iter]->{nbnd}=$2;
			$data[$iter]->{_natomwfc}=$3;
			$data[$iter]->{_npwx}=$4;
		}
		if (/^\s*nelec\s*=\s*([0-9\.]+)\s*nkb\s*=\s*(\d+)\s*ngl\s*=\s*(\d+)\s*$/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{nelec}=$1;
			$data[$iter]->{_nkb}=$2;
			$data[$iter]->{_ngl}=$3;
		}
		## END stuff found in version 3.2
		if (/^\s*Program PWSCF v.(\S+)/) {
			$fh_parsed=__LINE__-1;
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
			$fh_parsed=__LINE__-1;
			$data[$iter]->{bands}=parse_bands($fh,$data[0]->{nk},$data[0]->{nbnd},$fh_line,$options);
			$fh_line='';
			next;
		}

		if (/^\s*crystal axes: \(cart\. coord/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$fh_line='';
			$data[$iter]->{amat}=zeroes(3,3);
			for (my $i=0; $i<3 ; $i++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				s/-/ -/g;
				if (/^.*\(\s*([^\)]+)\s*\)/) {
					$data[$iter]->{amat}->(:,$i;-) .= pdl(split /\s+/,$1);
				}
			}
			next;
		}

		if (/^\s*reciprocal axes: \(cart\. coord/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$fh_line='';
			$data[$iter]->{bmat}=zeroes(3,3);
			for (my $i=0; $i<3 ; $i++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				s/-/ -/g;
				if (/^.*\(\s*([^\)]+)\s*\)/) {
					$data[$iter]->{bmat}->(:,$i;-) .= pdl(split /\s+/,$1);
				}
			}
			next;
		}
		if (/^\s*atomic species   valence    mass     pseudopotential/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$fh_line='';
			for (my $i=1; $i<$data[0]->{ntyp} ; $i++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				# nerv...
				if (/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(.*)\s*$/) {
					$data[$iter]->{species_index}->{$1}=$i;
					$data[$iter]->{species}->[$i]->{label}=$1;
					$data[$iter]->{species}->[$i]->{valence}=$2;
					$data[$iter]->{species}->[$i]->{mass}=$3;
					$data[$iter]->{species}->[$i]->{pseudopotential}=$4;
				}
			}
			next;
		}
		if (/^\s*Starting magnetic structure/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$fh_line='';
			$_=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
			for (my $i=1; $i<$data[0]->{ntyp} ; $i++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				if (/^\s*(\S+)\s+(\S+)\s*$/) {
					$data[$iter]->{species}->[$i]->{starting_magnetization}=$2
				}
			}
			next;
		}
		if (/\s*Cartesian axes/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$data[$iter]->{ATOMIC_POSITIONS_CARTESIAN}=zeroes(3,$data[0]->{nat});
			$_=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
			$_=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
			for (my $at_counter=0;$at_counter<$data[0]->{nat};$at_counter++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				last if (/^\s*$/);
				# match line:
				#          1           Cu1 tau(  1) = (  -0.5000000   0.0000000  -0.2916537  )
				if (/^\s*(\d+)\s+(\S+)\s+tau\(\s*(\d+)\)\s*=\s*\(\s*(\S+)\s+(\S+)\s+(\S+)\s*\)\s*$/) {
					$data[$iter]->{ATOMIC_POSITIONS_CARTESIAN}->(:,$at_counter;-).=pdl($4,$5,$6);
					$data[$iter]->{atom_species}->[$1]=$2;
					push @{$data[$iter]->{species_atoms}->{$2}},$1;
				}
			}
			$fh_line='';
			next;
		}
		if (/\s*Crystallographic axes/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$data[$iter]->{ATOMIC_POSITIONS}=zeroes(3,$data[0]->{nat});
			$_=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
			$_=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
			for (my $at_counter=0;$at_counter<$data[0]->{nat};$at_counter++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				last if (/^\s*$/);
				# match line:
				#          1           Cu1 tau(  1) = (  -0.5000000   0.0000000  -0.2916537  )
				if (/^\s*(\d+)\s+(\S+)\s+tau\(\s*(\d+)\)\s*=\s*\(\s*(\S+)\s+(\S+)\s+(\S+)\s*\)\s*$/) {
					$data[$iter]->{ATOMIC_POSITIONS}->(:,$at_counter;-).=pdl($4,$5,$6);
				}
			}
			$fh_line='';
			next;
		}

		if (/^\s*celldm/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{celldm}=zeroes(6) unless exists ($data[$iter]->{celldm});
			my $celldm=$data[$iter]->{celldm};
			s/celldm\((\d+)\)=/$1/g;
			my @data=split;
			for (my $i=0;$i<$#data+1;$i+=2) {
				my $dm=$data[$i]-1;
				$celldm->($dm).=$data[$i+1];
			}
			next;
		}

		if (/\s*entering subroutine stress/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$data[$iter]->{stress}= parse_stress($fh,$options);
			$fh_line='';
			next;
		}
		if (/\s*CELL_PARAMETERS\s*\(alat=\s*([0-9\.]+)/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$data[$iter]->{CELL_PARAMETERS_alat}=$1;
			$data[$iter]->{CELL_PARAMETERS}=zeroes(3,3);
			for (my $row=0;$row<3;$row++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				$data[$iter]->{CELL_PARAMETERS}->(:,$row;-).=pdl(split);
			}
			$fh_line='';
			next;
		}
		if (/\s*ATOMIC_POSITIONS/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			$data[$iter]->{ATOMIC_POSITIONS}=zeroes(3,$data[0]->{nat});
			for (my $at_counter=0;$at_counter<$data[0]->{nat};$at_counter++) {
				$_=<$fh>;
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				last if (/^\s*$/);
				my ($type,@position)=split;
				$data[$iter]->{ATOMIC_POSITIONS}->(:,$at_counter;-).=pdl(@position);
			}
			$fh_line='';
			next;
		}
		if (/^\s*Total force\s*=\s*([0-9\.]+)\s*/) {
			$fh_parsed=__LINE__-1;
			$data[$iter]->{force_total}=$1;
			next;
		}
		if (/^\s*from (\S+)\s*:\s*error\s*#\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line) if ($annotated_debug_fh);
			my ($err_name,$err_num)=($1,$2);
			my @err_msg;
			while (<$fh>) {
				annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$_) if ($annotated_debug_fh);
				chomp;
				last if (/%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%/);
				s/^\s*//;
				s/\s*$//;
				push @err_msg,$_;
			}
			$data[$iter]->{error}->{$err_name}->[0]=$err_num;
			$data[$iter]->{error}->{$err_name}->[1]=join("\n",@err_msg);
			$fh_line='';
			next;
		}
	} continue {
		annotate_debug($annotated_debug_fh,'parse_pw_out',$fh_parsed,$fh_line)
			if ($annotated_debug_fh and $fh_line);
	}
	close($fh);
	close($options->{ANNOTATED_DEBUG_FH}) if ($options->{ANNOTATED_DEBUG_FILE});
	if ($options->{CACHE}>0) {
		if (fdump(\@data,$cachefile)) {
				print STDERR "Written to cachefile $cachefile\n" if ($options->{VERBOSE}>0);
		}
	}
	return(\@data);
}

sub parse_write_ns {
	my $fh=shift;
	my $options=shift;
	my ($atom,$spin);
	my $result;
	my (@atoms,@species);
	my $in_occupations;
	my $in_eigenvectors;
	my $annotated_debug_fh=$options->{ANNOTATED_DEBUG_FH} if (exists $options->{ANNOTATED_DEBUG_FH});
	my $fh_line='';
	my $fh_parsed;
	$in_occupations=$in_eigenvectors=0;
	$atom=$spin=0;
	while (<$fh>) {
		$fh_line=$_;
		chomp;
		$fh_parsed=0;
		if (/^ exit write_ns/) {
			$fh_parsed=__LINE__-1;
			last;
		}
		if (/^U\(/) {
			$fh_parsed=__LINE__-1;
			while (/U\(\s*(\d+)\)\s*=\s*(\d+\.\d+)/g) {
				$species[$1]->{U}=$2;
			}
			next;
		}
		if (/^alpha\(/) {
			$fh_parsed=__LINE__-1;
			while (/alpha\(\s*(\d+)\)\s*=\s*(-?\d+\.\d+)/g) {
				$species[$1]->{alpha}=$2;
			}
			next;
		}
		if (/^atom\s*(\d+)\s*Tr\[ns\(na\)\]=\s*(\d+\.\d+)/) {
			$fh_parsed=__LINE__-1;
			$in_occupations=0;
			$atoms[$1]->{Trns}=$2;
			next;
		}
		if (/^atom\s*(\d+)\s*spin\s*(\d+)/) {
			$fh_parsed=__LINE__-1;
			$atom=$1;
			$spin=$2;
			next;
		}
		if (s/^eigenvalues:\s*//) {
			$fh_parsed=__LINE__-1;
			@{$atoms[$atom]->{spin}->[$spin]->{eigenvalues}}=split;
			next;
		}
		if (/^ occupations/) {
			$fh_parsed=__LINE__-1;
			$in_occupations=1;
			$in_eigenvectors=0;
			next;
		}
		if (/^ eigenvectors/) {
			$fh_parsed=__LINE__-1;
			$in_eigenvectors=1;
			next;
		}
		if (/^nsum\s*=\s*(\d+\.\d+)/) {
			$fh_parsed=__LINE__-1;
			$in_occupations=0;
			$result->{nsum}=$1;
			next;
		}
		if ($in_eigenvectors) {
			$fh_parsed=__LINE__-1;
			my ($idx,@vec)=split;
			@{$atoms[$atom]->{spin}->[$spin]->{eigenvectors}->[$idx-1]}=@vec;
			next;
		}
		if ($in_occupations) {
			$fh_parsed=__LINE__-1;
			my (@line)=split;
			push @{$atoms[$atom]->{spin}->[$spin]->{occupations}},\@line;
			next;
		}
	} continue {
		annotate_debug($annotated_debug_fh,'parse_write_ns',$fh_parsed,$fh_line)
			if ($annotated_debug_fh and $fh_line);
	}
	annotate_debug($annotated_debug_fh,'parse_write_ns',$fh_parsed,$fh_line)
		if ($annotated_debug_fh and $fh_line);
	$result->{atoms}=\@atoms;
	$result->{species}=\@species;
	return($result);
}

sub parse_bands {
	my $fh=shift;
	my $nk=shift;
	my $nbnd=shift;
	my $firstline = shift;
	my $options=shift;
	my $annotated_debug_fh=$options->{ANNOTATED_DEBUG_FH} if (exists $options->{ANNOTATED_DEBUG_FH});
	my $fh_line='';
	my $fh_parsed;
	my $result;
	my $ik=-1;
	my @accum;
	my $hot=0;
	my $expect_occupation=0;

	my $dimensions_unknown = 0;
	if (! defined $nk) {
		print STDERR "parse_bands: \$nk undefined!\n";
		$dimensions_unknown = 1;
	}
	if (! defined $nbnd) {
		print STDERR "parse_bands: \$nbnd undefined!\n";
		$dimensions_unknown = 1;
	}
	return undef if ($dimensions_unknown);

	$result->{kvec}=zeroes(3,$nk);
	$result->{npw}=zeroes(long,$nk);
	$result->{ebnd}=zeroes($nbnd,$nk);

	while (((defined $firstline) ? ($_=$firstline) : ($_=<$fh>))) {
		$firstline=undef;
		$fh_line=$_;
		$fh_parsed=0;
		chomp;
		# insert spaces in front of minus signs to work around broken pw format strings
		s/-/ -/g;
		if ($hot and /^\s*$/) {
			$fh_parsed=__LINE__-1;
			if ($options->{DEBUG_BANDS_ACCUM}>0) {
				print STDERR "$ik/$nk: $#accum\n";
				print STDERR join(" ",@accum) . "\n";
			}
			if ($hot==1) {
				$result->{ebnd}->(:,$ik;-).=pdl(@accum);
			} elsif ($hot==2) {
				$result->{occupation}->(:,$ik;-).=pdl(@accum);
			}
			@accum=();
			$hot=0;
			last if (($ik==$nk-1) and ($expect_occupation==0));
		}
		if (/^\s*k =\s*(.*) \(\s*(\d+) PWs\)   bands \(ev\):\s*$/) {
			$fh_parsed=__LINE__-1;
			annotate_debug($annotated_debug_fh,'parse_bands',$fh_parsed,$fh_line)
				if ($annotated_debug_fh);
			$ik++;
			$result->{npw}->($ik).=$2;
			$result->{kvec}->(:,$ik;-).=pdl(split /\s+/,$1);
			$fh_line=<$fh>;
			annotate_debug($annotated_debug_fh,'parse_bands',$fh_parsed,$fh_line)
				if ($annotated_debug_fh);
			$fh_line='';
			$hot=1;
			next;
		}
		if (/^\s*occupation numbers\s*$/) {
			$fh_parsed=__LINE__-1;
			unless (exists $result->{occupation}) {
				$expect_occupation=$nk;
				$result->{occupation}=zeroes($nbnd,$nk);
			}
			$expect_occupation--;
			$hot=2;
			next;
		}
		if ($hot) {
			$fh_parsed=__LINE__-1;
			push @accum,split;
			next;
		}
	} continue {
		annotate_debug($annotated_debug_fh,'parse_bands',$fh_parsed,$fh_line)
			if ($annotated_debug_fh and $fh_line);
	};
	annotate_debug($annotated_debug_fh,'parse_bands',$fh_parsed,$fh_line)
		if ($annotated_debug_fh and $fh_line);
	return $result;
}

sub parse_stress {
	my $fh=shift;
	my $options=shift;
	my $annotated_debug_fh=$options->{ANNOTATED_DEBUG_FH} if (exists $options->{ANNOTATED_DEBUG_FH});
	my $fh_line='';
	my $fh_parsed;
	my $result;
	my $row=-1;
	$result->{au}=zeroes(3,3);
	$result->{kbar}=zeroes(3,3);
	while (<$fh>) {
		$fh_line=$_;
		chomp;
		$fh_parsed=0;
		if (/^\s*total\s*stress.*P=\s*(\S+)\s*$/) {
			$fh_parsed=__LINE__-1;
			$row=0;
			$result->{P}=$1;
			next;
		}
		if ($row>=0 and /^\s*$/) {
			$fh_parsed=__LINE__-1;
			last;
		}
		if ($row>=0) {
			$fh_parsed=__LINE__-1;
			my @line=split;
			$result->{au}->(:,$row).=pdl(@line[0..2]);
			$result->{kbar}->(:,$row).=pdl(@line[3..5]);
			$row++;
		}
	} continue {
		annotate_debug($annotated_debug_fh,'parse_stress',$fh_parsed,$fh_line)
			if ($annotated_debug_fh and $fh_line);
	};
	annotate_debug($annotated_debug_fh,'parse_stress',$fh_parsed,$fh_line)
		if ($annotated_debug_fh and $fh_line);

	return ($row > 2 ? $result : undef);
}

1;
