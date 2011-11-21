package Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_SPECIES;
use strict;
use warnings;
use Chemistry::Simulation::QuantumEspresso::pw::in::card;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_SPECIES::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}='ATOMIC_SPECIES';
	$self->{species}  = {};
	$self->{_species} = [];
	if ($#args >= 0) {
		return($self->parse(@args));
	}
	return(undef,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	my $o_line = $self->{o_b} = $o_lines->[$i];
	if ($lines_cs->[$i] =~ /^\s*(ATOMIC_SPECIES)/) {
		$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
	}
	my $ntyp=$self->{_namelist}->get('&system','ntyp');
	while (1) {
		$i++;
		last if ($#{$self->{_species}} >= $ntyp-1);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)/) {
			my $species=Fortran::Namelist::Editor::ContainerSpan->new($self->{_namelist},$o_line,$o_lines->[$i+1]-1);
			$species->{label}           = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			$species->{mass}            = Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
			$species->{pseudopotential} = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]);
			$self->{species}->{$species->{label}->get}=$species;
			push @{$self->{_species}},$species;
		} else {
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{_species}} < $ntyp-1) {
		warn "Card 'ATOMIC_SPECIES' incomplete";
	}
	return($i,$self);
}

sub get {
	my $self = shift;
	my $h = $self->SUPER::get();
	for my $species (@{$self->{_species}}) {
		push @{$h->{species}},$species->get;
	}
	return($h);
}
1;
