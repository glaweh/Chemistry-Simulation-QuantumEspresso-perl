package Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS;
use strict;
use warnings;
use Chemistry::Simulation::QuantumEspresso::pw::in::card;
use Scalar::Util qw{blessed};
@Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}     ='CELL_PARAMETERS';
	$self->{symmetry} = undef;
	$self->{v}        = [];
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
	if ($title =~ /^\s*(CELL_PARAMETERS)(?:\s+\S*(cubic|hexagonal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{_o}->[0]=$o_line;
		$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{symmetry}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
		} else {
			$self->{symmetry} = 'cubic';
		}
	}

	while (1) {
		$i++;
		last if ($#{$self->{v}} >= 2);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s(\s*\S+)\s(\s*\S+)/) {
			my $vec = [
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			];
			push @{$self->{v}},$vec;
		}
	}
	$self->{_o}->[1]=$o_lines->[$i]-1;
	if ($#{$self->{v}} < 2) {
		warn "Card 'CELL_PARAMETERS' incomplete";
	}
	return($i,$self);
}

sub _get_symmetry {
	my ($self,$value)=@_;
	return($self->{symmetry}->get()) if (blessed($self->{symmetry}));
	return($self->{symmetry});
}

sub _set_symmetry {
	my ($self,$value)=@_;
	return($self->{symmetry}->set($value)) if (blessed($self->{symmetry}));
	my $adj;
	($self->{symmetry},$adj) = Fortran::Namelist::Editor::Token->insert($self->{_namelist},$self->{name}->{_o}->[1],' ',$value);
	return($adj);
}

sub _get_vec {
	my ($self,@index) = @_;
	my @result;
	if ($#index < 0) {
		for my $vec (@{$self->{v}}) {
			push @result, [ map { $_->get } @{$vec} ];
		}
	} elsif ($#index == 0) {
		@result = map { $_->get } @{$self->{v}->[$index[0]]};
	} else {
		return($self->{v}->[$index[0]]->[$index[1]]->get);
	}
	return(\@result);
}

sub get {
	my ($self,$var,@index) = @_;
	if (! defined $var) {
		my $h = $self->SUPER::get();
		$h->{v}=$self->_get_vec();
		$h->{symmetry}=$self->_get_symmetry();
		return($h);
	} else {
		if ($var eq 'symmetry') {
			return($self->_get_symmetry());
		} elsif ($var eq 'v') {
			return($self->_get_vec(@index));
		} else {
			return(undef);
		}
	}
}

sub _set_vec {
	my ($self,$value,@index) = @_;
	my @adj;
	if ($#index < 0) {
		for (my $i=0;$i<3;$i++) {
			for (my $j=0;$j<3;$j++) {
				push @adj,$self->{v}->[$i]->[$j]->set_padded($value->[$i]->[$j]);
			}
		}
	} elsif ($#index==0) {
		for (my $i=0;$i<3;$i++) {
			push @adj,$self->{v}->[$index[0]]->[$i]->set_padded($value->[$i]);
		}
	} else {
		return($self->{v}->[$index[0]]->[$index[1]]->set_padded($value));
	}
	return(Fortran::Namelist::Editor::Span::summarize_adj(@adj));
}

sub set {
	my ($self,$var,$value,@index) = @_;
	if ($var eq 'symmetry') {
		return($self->_set_symmetry($value));
	} elsif ($var eq 'v') {
		return($self->_set_vec($value,@index));
	}
}
1;
