package Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_POSITIONS;
use strict;
use warnings;
use Chemistry::Simulation::QuantumEspresso::IN::pw::card;
use Scalar::Util qw{blessed};
@Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_POSITIONS::ISA = qw{Chemistry::Simulation::QuantumEspresso::IN::pw::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}  ='ATOMIC_POSITIONS';
	$self->{units} = undef;
	$self->{atom}  = {};
	$self->{_atom} = [ ];
	return(undef,$self);
}

sub parse {
	my ($class,$namelist,$lines,$lines_cs,$o_lines,$i) = @_;
	my $self = $class->new($namelist);
	# check for units
	my $title = $lines_cs->[$i];
	while ($title =~ /__+/) {
		substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
	}
	if ($title =~ /^\s*(ATOMIC_POSITIONS)(?:\s+\S*(alat|bohr|angstrom|crystal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{_o}->[0] = $o_line;
		$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{units}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
		} else {
			$self->{units} = 'alat';
		}
	}

	my $nat=$self->{_namelist}->get('&system','nat');
	while (1) {
		$i++;
		last if ($#{$self->{_atom}} >= $nat-1);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s(\s*\S+)\s(\s*\S+)\s(\s*\S+)(?:\s+(\S+)\s+(\S+)\s+(\S+))?/) {
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
	$self->{_o}->[1]=$o_lines->[$i]-1;
	if ($#{$self->{_atom}} < $nat-1) {
		warn "Card 'ATOMIC_POSITIONS' incomplete";
	}
	return($i,$self);
}

sub _get_units {
	my ($self,$value)=@_;
	return($self->{units}->get()) if (blessed($self->{units}));
	return($self->{units});
}

sub _set_units {
	my ($self,$value)=@_;
	return($self->{units}->set($value)) if (blessed($self->{units}));
	$self->{units} = Fortran::Namelist::Editor::Token->insert($self->{_namelist},$self->{name}->{_o}->[1],' ',$value);
	return(1);
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

sub _get_vec {
	my ($self,$var,@index) = @_;
	my @result;
	if ($#index < 0) {
		for my $atom (@{$self->{_atom}}) {
			if (defined $atom->{$var}) {
				push @result, [ map { $_->get } @{$atom->{$var}} ];
			} else {
				push @result, [ 1, 1, 1];
			}
		}
	} elsif ($#index == 0) {
		if (defined $self->{_atom}->[$index[0]]->{$var}) {
			@result = map { $_->get } @{$self->{_atom}->[$index[0]]->{$var}};
		} else {
			push @result,1,1,1;
		}
	} else {
		return($self->{_atom}->[$index[0]]->{$var}->[$index[1]]->get) if (defined $self->{_atom}->[$index[0]]->{$var});
		return(undef);
	}
	return(\@result);
}

sub get {
	my ($self,$variable,@index)=@_;
	unless (defined $variable) {
		my $h;
		$h->{units}    = $self->get('units');
		$h->{species}  = $self->get('species');
		$h->{position} = $self->get('position');
		$h->{if_pos}   = $self->get('if_pos');
		return($h);
	}
	return($self->_get_units()) if ($variable eq 'units');
	if ($variable eq 'species') {
		if ($#index < 0) {
			return([ map { $_->{species}->get() } @{$self->{_atom}} ]);
		} else {
			return($self->{_atom}->[$index[0]]->{species}->get());
		}
	}
	return(undef) unless ($variable =~ /^position|if_pos$/);
	return($self->_get_vec($variable,@index));
}

sub _insert_ifpos {
	my ($self,$value,$atom) = @_;
	return(undef) unless defined ($value);
	return(undef) if (defined $atom->{if_pos});
	my $o_b = $atom->{_o}->[1];
	$self->{_namelist}->set_data($o_b,$o_b,"  " . join("  ",@{$value}));
	for (my $i=0;$i<3;$i++) {
		push @{$atom->{if_pos}},
			Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_b+2,$o_b+2+length($value->[$i]));
		$o_b=$o_b+2+length($value->[$i]);
	}
	return(1);
}

sub _set_vec {
	my ($self,$var,$value,@index) = @_;
	my $nat = $self->{_namelist}->get('&system','nat');
	if ($#index < 0) {
		die "dimension mismatch" unless ((ref($value) eq 'ARRAY') and ($#{$value}==$nat-1));
		for (my $i=0;$i<$nat;$i++) {
			if (defined $self->{_atom}->[$i]->{$var}) {
				for (my $j=0;$j<3;$j++) {
					$self->{_atom}->[$i]->{$var}->[$j]->set_padded(sprintf('%14.10f',$value->[$i]->[$j]));
				}
			} else {
				$self->_insert_ifpos($value->[$i],$self->{_atom}->[$i]);
			}
		}
	} elsif ($#index==0) {
		if (defined $self->{_atom}->[$index[0]]->{$var}) {
			for (my $i=0;$i<3;$i++) {
				$self->{_atom}->[$index[0]]->{$var}->[$i]->set_padded($value->[$i]);
			}
		} else {
			$self->_insert_ifpos($value,$self->{_atom}->[$index[0]]);
		}
	} else {
		if (defined $self->{_atom}->[$index[0]]->{$var}) {
			return($self->{_atom}->[$index[0]]->{$var}->[$index[1]]->set_padded($value));
		} else {
			my $setting = [ 1, 1, 1];
			$setting->[$index[1]]=$value;
			return($self->_insert_ifpos($setting,$self->{_atom}->[$index[0]]));
		}
	}
	return(1);
}

sub set {
	my ($self,$var,$value,@index) = @_;
	if ($var eq 'units') {
		return($self->_set_units($value));
	} else {
		return($self->_set_vec($var,$value,@index));
	}
}
1;
