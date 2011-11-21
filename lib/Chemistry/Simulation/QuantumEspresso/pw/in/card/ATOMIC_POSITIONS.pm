package Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_POSITIONS;
use strict;
use warnings;
use Chemistry::Simulation::QuantumEspresso::pw::in::card;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_POSITIONS::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}  ='ATOMIC_POSITIONS';
	$self->{units} = undef;
	$self->{atom}  = {};
	$self->{_atom} = [ ];
	if ($#args >= 0) {
		return($self->parse(@args));
	}
	return(undef,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	# check for units
	my $title = $lines_cs->[$i];
	while ($title =~ /__+/) {
		substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
	}
	if ($title =~ /^\s*(ATOMIC_POSITIONS)(\s+\S*(alat|bohr|angstrom|crystal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{units}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		} else {
			substr($lines->[$i],$+[1],0) = ' alat';
			substr($lines_cs->[$i],$+[1],0) = ' alat';
			foreach (@{$o_lines}) {
				$_+=5 if ($_ > $o_line);
			}
			my $adj;
			($self->{units},$adj)=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','alat');
			$self->_adjust_offsets($adj);
		}
	}

	my $nat=$self->{_namelist}->get('&system','nat');
	while (1) {
		$i++;
		last if ($#{$self->{_atom}} >= $nat-1);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+)\s+(\S+)\s+(\S+))?/) {
			my $atom=Fortran::Namelist::Editor::ContainerSpan->new($self->{_namelist},$o_line,$o_lines->[$i+1]-1);
			$atom->{species}         = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			$atom->{position}        = [
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]),
			];
			if (defined $5) {
				$atom->{if_pos}      = [
					Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[5],$o_line+$+[5]),
					Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[6],$o_line+$+[6]),
					Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[7],$o_line+$+[7]),
				];
			}
			push @{$self->{_atom}},$atom;
			push @{$self->{atom}->{$atom->{species}->get}},$atom;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{_atom}} < $nat-1) {
		warn "Card 'ATOMIC_POSITIONS' incomplete";
	}
	return($i,$self);
}

sub get_species {
	my ($self,$index)=@_;
	if (defined $index) {
		if (defined $self->{_atom}->[$index]) {
			return($self->{_atom}->[$index]->{species}->get);
		} else {
			return(undef);
		}
	} else {
		my @species = map { $_->{species}->get } @{$self->{_atom}};
		return(\@species);
	}
}

sub get_position {
	my ($self,$index)=@_;
	if (defined $index) {
		if (defined $self->{_atom}->[$index]) {
			my @position=map { $_->get } @{$self->{_atom}->[$index]->{position}};
			return(\@position);
		} else {
			return(undef);
		}
	} else {
		my @position;
		foreach my $atom (@{$self->{_atom}}) {
			push @position,[ map { $_->get } @{$atom->{position}} ];
		}
		return(\@position);
	}
}

sub get_if_pos {
	my ($self,$index)=@_;
	if (defined $index) {
		if (defined $self->{_atom}->[$index] and defined $self->{_atom}->[$index]->{if_pos}) {
			my @if_pos=map { $_->get } @{$self->{_atom}->[$index]->{if_pos}};
			return(\@if_pos);
		} else {
			return(undef);
		}
	} else {
		my @if_pos;
		foreach my $atom (@{$self->{_atom}}) {
			if (defined $atom->{if_pos}) {
				push @if_pos,[ map { $_->get } @{$atom->{if_pos}} ];
			} else {
				push @if_pos,[ 1, 1, 1];
			}
		}
		return(\@if_pos);
	}
}

sub get {
	my $self=shift;
	my $h=$self->SUPER::get();
	$h->{species}  = $self->get_species;
	$h->{position} = $self->get_position;
	$h->{if_pos}   = $self->get_if_pos;
	return($h);
}
1;
