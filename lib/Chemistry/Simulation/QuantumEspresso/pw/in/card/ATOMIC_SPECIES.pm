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
	$self->{o_e}=$o_lines->[$i]-1;
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
	my $ntyp=$self->get('&system','ntyp');
	my @adj;
	if (! defined $index) {
		die "dimension mismatch" unless ((ref($value) eq 'ARRAY') and ($#{$value}==$ntyp-1));
		for (my $i=0; $i<$ntyp; $i++) {
			push @adj,$self->{_species}->[$i]->{$variable}->set_padded($value->[$i]);
		}
	} elsif ($index =~ /^\d+$/) {
		push @adj,$self->{_species}->[$index]->{$variable}->set_padded($value);
	} else {
		push @adj,$self->{species}->{$index}->{$variable}->set_padded($value);
	}
	if ($variable eq 'label') {
		%{$self->{species}}=map { $_->{label}->get(),$_ } @{$self->{_species}};
	}
	return(Fortran::Namelist::Editor::Span::summarize_adj(@adj));
}
1;
