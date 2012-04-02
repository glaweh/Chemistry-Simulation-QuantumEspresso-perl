package Chemistry::Simulation::QuantumEspresso::Cell;
use strict;
use warnings;
use PDL;
use PDL::NiceSlice;
our @bravais=qw/free cP cF cI hP hR tP tI oP oS oF oI mP mS aP/;
our %ibrav=map { ($bravais[$_],$_) } 0 .. $#bravais;

our @bravais_symm_class=qw/cubic
	cubic cubic cubic
	hexagonal hexagonal
	cubic cubic
	cubic cubic cubic cubic
	cubic cubic
	cubic/;

my $PI = 2*acos(0);

sub convcell2espresso {
	my ($bravais,$lengths,$cos)=@_;
	my $celldm=zeroes(double,6)/0; # a piddle of NaNs
	my $ibrav=$ibrav{$bravais};
	if ($bravais =~ /^c.$/) {
		$celldm(0).=$lengths(0);
	} elsif ($bravais eq 'hP') {
		$celldm(0).=$lengths(0);
		$celldm(2).=$lengths(2);
	} elsif ($bravais eq 'hR') {
		$celldm(0).=$lengths(0);
		$celldm(3).=$cos(0);
	} elsif ($bravais =~ /^t.$/) {
		$celldm(pdl(0,2)).=$lengths(pdl(0,2));
	} elsif ($bravais eq 'oA') {
		$ibrav = 9;
		$celldm(0:2) .= $lengths(0:2)->rotate(-1);
	} elsif ($bravais eq 'oB') {
		$ibrav = 9;
		$celldm(0:2) .= $lengths(0:2)->rotate(1);
	} elsif ($bravais eq 'oC') {
		$ibrav = 9;
		$celldm(0:2) .= $lengths(0:2);
	} elsif ($bravais =~ /^o.$/) {
		$celldm(0:2).=$lengths(0:2);
	} elsif ($bravais =~ /m[CS]/) {
		$ibrav = 13;
		$celldm(0:2).=$lengths(pdl(0,2,1));
		$celldm(3).=$cos(1);
	} elsif ($bravais =~ /^mP$/) {
		$celldm(0:2).=$lengths(pdl(0,2,1));
		$celldm(3).=$cos(1);
	} elsif ($bravais eq 'aP') {
		$celldm(0:2).=$lengths(0:2);
		$celldm(3:5).=$cos(0:2);
	} else {
		$@="Not implemented for bravais=$bravais!";
		return(undef);
	}
	$celldm(1:2)/=$celldm(0);
	return($ibrav, $celldm);
}

sub espresso_amat {
	my ($ibrav,$celldm)=@_;
	my ($a,$ba,$ca)=$celldm(0:2)->dog;
	my $cos=$celldm(3:5);
	my $sin=$cos->acos->sin;
	my $amat=identity(3);
	my $special_axis;
	my $centering;
	my $conv_cell;
	if ($ibrav == 1) {
		#cP
		$amat*=$a;
		$conv_cell=$amat->copy;
	} elsif ($ibrav == 2) {
		#cF
		$amat=pdl([[-1,0,1],[0,1,1],[-1,1,0]])*$a/2;
		$conv_cell=espresso_amat(1,$celldm);
	} elsif ($ibrav == 3) {
		#cI
		$amat=pdl([[1,1,1],[-1,1,1],[-1,-1,1]])*$a/2;
		$conv_cell=espresso_amat(1,$celldm);
	} elsif ($ibrav == 4) {
		#hP
		$amat(:,1).=pdl(-0.5,sqrt(3)/2,0);
		$amat(2,2).=$ca;
		$amat*=$a;
		$conv_cell=$amat->copy;
		$special_axis=2;
	} elsif ($ibrav == 5) {
		#hR
		my $tx=sqrt((1-$cos(0))/2);
		my $ty=sqrt((1-$cos(0))/6);
		my $tz=sqrt((1+2*$cos(0))/3);
		$amat(:,0;-).=flat(cat($tx,-$ty,$tz));
		$amat(:,1;-).=flat(cat(pdl(0),2*$ty,$tz));
		$amat(:,2;-).=flat(cat(-$tx,-$ty,$tz));
		$amat*=$a;
		$conv_cell=$amat->copy;
	} elsif ($ibrav == 6) {
		#tP
		$amat(2,2).=$ca;
		$amat*=$a;
		$conv_cell=$amat->copy;
		$special_axis=2;
	} elsif ($ibrav == 7) {
		#tI
		$amat(0:1,0;-).=pdl(1,-1);
		$amat(0:1,1;-).=pdl(1,1);
		$amat(0:1,2;-).=pdl(-1,-1);
		$amat(2,:;-).=$ca;
		$amat*=$a/2;
		$conv_cell=espresso_amat(6,$celldm);
		$special_axis=2;
	} elsif ($ibrav == 8) {
		#oP
		$amat(1,1).=$ba;
		$amat(2,2).=$ca;
		$amat*=$a;
		$conv_cell=$amat->copy;
	} elsif ($ibrav == 9) {
		#oS
		$amat(1,0:1).=$ba;
		$amat(0,1).=-1;
		$amat(2,2).=$ca*2;
		$amat*=$a/2;
		$conv_cell=espresso_amat(8,$celldm);
		$special_axis=2;
		$centering=2;
	} elsif ($ibrav == 10) {
		#oF
		$amat(1,1:2).=$ba;
		$amat(2,pdl(0,2)).=$ca;
		$amat(0,1).=1;
		$amat*=$a/2;
		$conv_cell=espresso_amat(8,$celldm);
	} elsif ($ibrav == 11) {
		#oI
		$amat(0,1:2).=-1;
		$amat(1,:;-).=flat(cat($ba,$ba,-$ba));
		$amat(2,:).=$ca;
		$amat*=$a/2;
		$conv_cell=espresso_amat(8,$celldm);
	} elsif ($ibrav == 12) {
		#mP
		$amat(:,1;-).=flat(cat($cos(0),$sin(0),pdl(0)))*$ba;
		$amat(2,2).=$ca;
		$amat*=$a;
		$conv_cell=$amat->copy;
		$special_axis=2;
	} elsif ($ibrav == 13) {
		#mS
		$amat(2,0).=-$ca;
		$amat(:,1;-).=flat(cat($cos(0),$sin(0),pdl(0)))*2*$ba;
		$amat(0,2).=1;
		$amat(2,2).=$ca;
		$amat*=$a/2;
		$conv_cell=espresso_amat(12,$celldm);
		$special_axis=2;
		$centering=1;
	} elsif ($ibrav == 14) {
		#aP
		$amat(:,1;-).=flat(cat($cos(2),$sin(2),pdl(0)))*$ba;
		$amat(0,2).=$cos(1);
		$amat(1,2).=($cos(0)-$cos(1)*$cos(2))/$sin(2);
		$amat(2,2).=sqrt(1+
			2*$cos(0)*$cos(1)*$cos(2)
			-$cos(0)*$cos(0)
			-$cos(1)*$cos(1)
			-$cos(2)*$cos(2)) / $sin(2);
		$amat(:,2)*=$ca;
		$amat*=$a;
		$conv_cell=$amat->copy;
	}
	return(wantarray ? ($amat,$conv_cell,$special_axis,$centering) : $amat);
}

sub bmat_from_amat {
	my $amat = shift;
	my $bmat = 2*$PI*crossp($amat->transpose->rotate(2)->transpose,$amat->transpose->rotate(1)->transpose)/det($amat);
	return($bmat);
}

sub amat_from_pw_in {
	my $in = shift;
	my $want_conv = shift;
	my $ibrav  = $in->get('&system','ibrav');
	my $celldm=zeroes(6);
	map { my $c=$in->get('&system','celldm',$_); $celldm($_).=$c if (defined $c) } 0 .. 5;
	my ($amat,$symm_class);
	if ($ibrav == 0) {
		my $cell_param = pdl($in->get('CELL_PARAMETERS','v'));
		$amat=$cell_param*$celldm(0);
		$symm_class=$in->get('CELL_PARAMETERS','symmetry');
	} else {
		if ($want_conv) {
			(undef,$amat) = espresso_amat($ibrav,$celldm);
		} else {
			$amat=espresso_amat($ibrav,$celldm);
		}
		$symm_class=$bravais_symm_class[$ibrav];
	}
	return($symm_class,$amat);
}

our (@ISA, @EXPORT_OK);
BEGIN {
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(&convcell2espresso &espresso_amat &bmat_from_amat &amat_from_pw_in);  # symbols to export on request
}
1;
