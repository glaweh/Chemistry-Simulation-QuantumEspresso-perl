package Chemistry::Simulation::QuantumEspresso::UPF;
use strict;
use warnings;
use XML::Simple;
use Switch;
# shamelessly stolen from espresso-4.2/Modules/funct.f90
#
# dft is the exchange-correlation functional, described by
# any nonconflicting combination of the following keywords
# (case-insensitive):
#
# Exchange:    "nox"    none                           iexch=0
#              "sla"    Slater (alpha=2/3)             iexch=1 (default)
#              "sl1"    Slater (alpha=1.0)             iexch=2
#              "rxc"    Relativistic Slater            iexch=3
#              "oep"    Optimized Effective Potential  iexch=4
#              "hf"     Hartree-Fock                   iexch=5
#              "pb0x"   PBE0 (Slater*0.75+HF*0.25)     iexch=6
#              "b3lp"   B3LYP(Slater*0.80+HF*0.20)     iexch=7
#              "kzk"    Finite-size corrections        iexch=8
#
# Correlation: "noc"    none                           icorr=0
#              "pz"     Perdew-Zunger                  icorr=1 (default)
#              "vwn"    Vosko-Wilk-Nusair              icorr=2
#              "lyp"    Lee-Yang-Parr                  icorr=3
#              "pw"     Perdew-Wang                    icorr=4
#              "wig"    Wigner                         icorr=5
#              "hl"     Hedin-Lunqvist                 icorr=6
#              "obz"    Ortiz-Ballone form for PZ      icorr=7
#              "obw"    Ortiz-Ballone form for PW      icorr=8
#              "gl"     Gunnarson-Lunqvist             icorr=9
#              "b3lp"   B3LYP (same as "vwn")          icorr=10
#              "kzk"    Finite-size corrections        icorr=11
#
# Gradient Correction on Exchange:
#              "nogx"   none                           igcx =0 (default)
#              "b88"    Becke88 (beta=0.0042)          igcx =1
#              "ggx"    Perdew-Wang 91                 igcx =2
#              "pbx"    Perdew-Burke-Ernzenhof exch    igcx =3
#              "rpb"    revised PBE by Zhang-Yang      igcx =4
#              "hcth"   Cambridge exch, Handy et al    igcx =5
#              "optx"   Handy's exchange functional    igcx =6
#              "meta"   TPSS meta-gga                  igcx =7
#              "pb0x"   PBE0 (PBE exchange*0.75)       igcx =8
#              "b3lp"   B3LYP (Becke88*0.72)           igcx =9
#              "psx"    PBEsol exchange                igcx =10
#              "wcx"    Wu-Cohen                       igcx =11
#
# Gradient Correction on Correlation:
#              "nogc"   none                           igcc =0 (default)
#              "p86"    Perdew86                       igcc =1
#              "ggc"    Perdew-Wang 91 corr.           igcc =2
#              "blyp"   Lee-Yang-Parr                  igcc =3
#              "pbc"    Perdew-Burke-Ernzenhof corr    igcc =4
#              "hcth"   Cambridge corr, Handy et al    igcc =5
#              "meta"   TPSS meta-gga                  igcc =6
#              "b3lp"   B3LYP (Lee-Yang-Parr*0.81)     igcc =7
#              "psc"    PBEsol corr                    igcc =8
#
# Special cases (dft_shortname):
#              "bp"    = "b88+p86"           = Becke-Perdew grad.corr.
#              "pw91"  = "pw +ggx+ggc"       = PW91 (aka GGA)
#              "blyp"  = "sla+b88+lyp+blyp"  = BLYP
#              "pbe"   = "sla+pw+pbx+pbc"    = PBE
#              "revpbe"="sla+pw+rpb+pbc"     = revPBE (Zhang-Yang)
#              "pbesol"="sla+pw+psx+psc"     = PBEsol
#              "hcth"  = "nox+noc+hcth+hcth" = HCTH/120
#              "olyp"  = "nox+lyp+optx+blyp" = OLYP
#              "tpss"  = "sla+pw+meta+meta"  = TPSS Meta-GGA
#              "wc"    = "sla+pw+wcx+pbc"    = Wu-Cohen
#              "pbe0"  = "pb0x+pw+pb0x+pbc"  = PBE0
#              "hse"   = "nox+pw+hse+pbc"    = HSE
#              "b3lyp" = "b3lp+vwn+b3lp+b3lp"= B3LYP
my %dft_short_to_long = (
	"bp"    =>"sla+pz+b88+p86",
	"pw91"  =>"sla+pw+ggx+ggc",
	"blyp"  =>"sla+lyp+b88+blyp",
	"pbe"   =>"sla+pw+pbx+pbc",
	"revpbe"=>"sla+pw+rpb+pbc",
	"pbesol"=>"sla+pw+psx+psc",
	"hcth"  =>"nox+noc+hcth+hcth",
	"olyp"  =>"nox+lyp+optx+blyp",
	"tpss"  =>"sla+pw+meta+meta",
	"wc"    =>"sla+pw+wcx+pbc",
	"pbe0"  =>"pb0x+pw+pb0x+pbc",
	"hse"   =>"nox+pw+hse+pbc",
	"b3lyp" =>"b3lp+vwn+b3lp+b3lp",
# Henning's additions
	"pz"    =>"sla+pz+nogx+nogc"
);
my %dft_long_to_short = (
	# Henning's additions
	"sla+pw+pbe+pbe" => "pbe",
	"sla+pw+tpss+tpss" => "tpss",
);

# initialize vars
sub init {
	foreach my $short (keys %dft_short_to_long) {
		my $long = $dft_short_to_long{$short};
		$dft_long_to_short{$long}=$short;
	}
}



# subroutines
sub map_to_short_dft {
	my $long=lc(join('+',@_));
	if (exists $dft_long_to_short{$long}) {
		return $dft_long_to_short{$long};
	} else {
		return $long;
	}
}

sub read_header_upf_v1 {
	my $fname_upf=shift;
	my %simple_fields=(
		1 => 'version',
		2 => 'element',
		6 => 'z_valence',
		7 => 'etotps',
		9 => 'lmax',
		10 => 'mesh'
	);
	my %pseudo_type_map=(
		US => 'USPP',
		NC => 'NC',
		PAW => 'PAW'
	);
	my ($upf,$header_line,$exit,%data);
	open($upf,$fname_upf);
	$header_line=$exit=0;
	while (<$upf>) {
		chomp;
# 		printf "%03d '%s'\n",$header_line,$_;
		if (s/\s*<PP_HEADER>\s*//i) {
			$header_line=1;
		}
		next unless ($header_line);
		if (s/\s*<\/PP_HEADER>\s*//i) {
			$exit=1;
		}
		next if (/^\s*$/);
		my @line=split;
		if ($header_line <= 12) {
			switch ($header_line) {
				case (%simple_fields) {
					$data{$simple_fields{$header_line}}=$line[0];
				}
				case 3 { $data{pseudo_type}=$pseudo_type_map{$line[0]} }
				case 4 { $data{core_correction}=($line[0] =~ /tT/); }
				case 5 { $data{functional} = map_to_short_dft(@line[0 .. 3]); }
				case 8 { (@data{'ecutwfc','ecutrho'}) = @line[0,1]; }
				case 11 { (@data{'natwfc','nbeta'}) = @line[0,1]; }
			}
		} else {
			push @{$data{wavefunctions}}, {
				els  => $line[0],
				lchi => $line[1],
				oc   => $line[2] };
		}
		$header_line++;
	} continue {
		last if ($exit);
	}
	close($upf);
	if ($header_line > 0) {
		return \%data;
	} else {
		return undef;
	}
}
sub read_header_upf_v2 {
	my $fname_upf=shift;
	my $upf;
	eval {
		$upf=XMLin($fname_upf,KeepRoot=>1);
	};
	if ((defined $upf) and (exists $upf->{UPF}) and (exists $upf->{UPF}->{PP_HEADER})) {
		my %data=%{$upf->{UPF}->{PP_HEADER}};
		$data{version}=$upf->{version};
		$_=$data{functional};
		$data{functional}=map_to_short_dft(split);
		return \%data;
	} else {
		return undef;
	}
}
sub parse {
	my $fname_upf = shift;
	my $data;
	$data=read_header_upf_v1($fname_upf) unless (defined ($data=read_header_upf_v2($fname_upf)));
	next unless (defined $data);
	$data->{element}=~ s/^\s*//;
	$data->{element}=ucfirst(lc($data->{element}));
	return($data);
}


init();
1;
