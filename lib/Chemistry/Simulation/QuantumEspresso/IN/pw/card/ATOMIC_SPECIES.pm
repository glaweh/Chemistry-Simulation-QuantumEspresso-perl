package Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_SPECIES;
use strict;
use warnings;
use Chemistry::Simulation::QuantumEspresso::IN::pw::card;
@Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_SPECIES::ISA = qw{Chemistry::Simulation::QuantumEspresso::IN::pw::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}='ATOMIC_SPECIES';
	$self->{species}  = {};
	$self->{_species} = [];
	return(undef,$self);
}

sub parse {
	my ($class,$namelist,$lines,$lines_cs,$o_lines,$i) = @_;
	my $self = $class->new($namelist);
	my $o_line = $self->{_o}->[0] = $o_lines->[$i];
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
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s(\s*\S+)\s(\s*\S+)/) {
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
	$self->{_o}->[1]=$o_lines->[$i]-1;
	if ($#{$self->{_species}} < $ntyp-1) {
		warn "Card 'ATOMIC_SPECIES' incomplete";
	}
	return($i,$self);
}

sub get {
	my ($self,$variable,$index) = @_;
	unless (defined $variable) {
		my $h;
		$h->{label}   = $self->get('label');
		$h->{mass}    = $self->get('mass');
		$h->{pseudopotential}=$self->get('pseudopotential');
		return($h);
	}
	return(undef) unless ($variable =~ /^label|mass|pseudopotential$/);
	if (! defined $index) {
		return([ map { $_->{$variable}->get() } @{$self->{_species}} ]);
	} elsif ($index =~ /^\d+$/) {
		return($self->{_species}->[$index]->{$variable}->get);
	} else {
		return($self->{species}->{$index}->{$variable}->get);
	}
}

sub set {
	my ($self,$variable,$value,$index) = @_;
	return(undef) unless ($variable =~ /^label|mass|pseudopotential$/);
	my $ntyp=$self->{_namelist}->get('&system','ntyp');
	if (! defined $index) {
		die "dimension mismatch" unless ((ref($value) eq 'ARRAY') and ($#{$value}==$ntyp-1));
		for (my $i=0; $i<$ntyp; $i++) {
			$self->{_species}->[$i]->{$variable}->set_padded($value->[$i]);
		}
	} elsif ($index =~ /^\d+$/) {
		$self->{_species}->[$index]->{$variable}->set_padded($value);
	} else {
		$self->{species}->{$index}->{$variable}->set_padded($value);
	}
	if ($variable eq 'label') {
		%{$self->{species}}=map { $_->{label}->get(),$_ } @{$self->{_species}};
	}
	return(1);
}
1;
