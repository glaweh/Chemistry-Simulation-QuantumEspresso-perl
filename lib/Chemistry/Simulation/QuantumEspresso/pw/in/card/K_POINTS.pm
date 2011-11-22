package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS;
use strict;
use warnings;
use Scalar::Util qw{blessed};
use Chemistry::Simulation::QuantumEspresso::pw::in::card;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}     ='K_POINTS' unless (exists $self->{name});
	$self->{units}    = undef     unless (exists $self->{units});
	if ($#args >= 0) {
		return($self->parse(@args));
	}
	return(undef,$self) if (wantarray);
	return($self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	# check for units
	unless (defined $self->{units}) {
		my $title = $lines_cs->[$i];
		while ($title =~ /__+/) {
			substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
		}
		if ($title =~ /^\s*(K_POINTS)(?:\s+\S*(tpiba|automatic|crystal|gamma|tpiba_b|crystal_b)\S*)?/i) {
			my $o_line = $o_lines->[$i];
			$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			if (defined $2) {
				$self->{units}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
			} else {
				substr($lines->[$i],$+[1],0) = ' tpiba';
				substr($lines_cs->[$i],$+[1],0) = ' tpiba';
				foreach (@{$o_lines}) {
					$_+=6 if ($_ > $o_line);
				}
				my $adj;
				($self->{units},$adj)=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','tpiba');
				$self->_adjust_offsets($adj);
			}
		}
		my $units=$self->{units}->get;
		if ($units eq 'gamma') {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma');
		} elsif ($units eq 'automatic') {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic');
		} else {
			bless($self,'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list');
		}
		return($self->parse($lines,$lines_cs,$o_lines,$i));
	}
	return($i,$self);
}

sub get {
	my ($self,$variable,@index)=@_;
	unless (defined $variable) {
		my $h;
		$h->{units} = $self->get('units');
		return($h);
	}
	return($self->{units}->get()) if ($variable eq 'units');
	return(undef);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	return($i+1,$self);
}
sub set {
	my ($self,$variable,$value,@index)=@_;
	return(undef) unless (defined $variable);
	return(undef) unless (defined $value);
	if ($variable eq 'units') {
		if ($value ne 'gamma') {
			die "cannot change units from 'gamma' to '$value'";
		}
	}
	die "unknown variable '$variable'";
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->{nk}=[];
	$self->{sk}=[];
	return($self->SUPER::init($namelist,@args));
}
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	($i,$self)=$self->SUPER::parse($lines,$lines_cs,$o_lines,$i);
	while (1) {
		$i++;
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			@{$self->{nk}}=(
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			);
			@{$self->{sk}}=(
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[5],$o_line+$+[5]),
				Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[6],$o_line+$+[6]),
			);
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{nk}} < 2) {
		warn "Card 'K_POINTS' incomplete";
	}
	return($i,$self);
}
sub get {
	my ($self,$variable,@index)=@_;
	my $result=$self->SUPER::get($variable,@index);
	if (! defined $variable) {
		$result->{nk}=$self->get('nk');
		$result->{sk}=$self->get('sk');
	}
	return($result) if defined ($result);
	if ($variable eq 'nk') {
		return([ map { $_->get } @{$self->{nk}} ]);
	} elsif ($variable eq 'sk') {
		return([ map { $_->get } @{$self->{sk}} ]);
	}
	return(undef);
}
sub set {
	my ($self,$variable,$value,@index)=@_;
	return(undef) unless (defined $variable);
	return(undef) unless (defined $value);
	if ($variable eq 'units') {
		if ($value ne 'automatic') {
			die "cannot change units from 'automatic' to '$value'";
		}
	}
	my @adj;
	if (($variable eq 'nk') or ($variable eq 'sk')) {
		if ($#index < 0) {
			for (my $i=0; $i<3; $i++) {
				push @adj,$self->{$variable}->[$i]->set_padded($value->[$i]);
			}
		} else {
			push @adj,$self->{$variable}->[$index[0]]->set_padded($value);
		}
	} else {
		die "unknown variable '$variable'";
	}
	return(Fortran::Namelist::Editor::Span::summarize_adj(@adj));
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->{nks}=undef;
	$self->{xk}  = [];
	$self->{wk}  = [];
	return($self->SUPER::init($namelist,@args));
}
sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	($i,$self)=$self->SUPER::parse($lines,$lines_cs,$o_lines,$i);
	my $nks;
	while (1) {
		$i++;
		last if ((defined $nks) and ($#{$self->{k}} >= $nks-1));
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s*$/) {
			$self->{nks}=Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			$nks=$self->{nks}->get;
		}
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
			push @{$self->{xk}},[
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			];
			push @{$self->{wk}},
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]);
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ((! defined $nks) or ($#{$self->{xk}} < $nks-1)) {
		warn "Card 'K_POINTS' incomplete";
	}
	return($i,$self);
}
sub get {
	my ($self,$variable,@index)=@_;
	my $result=$self->SUPER::get($variable,@index);
	if (! defined $variable) {
		$result->{nks} = $self->get('nks');
		$result->{xk}  = $self->get('xk');
		$result->{wk}  = $self->get('wk');
	}
	return($result) if defined ($result);
	return($self->{nks}->get) if ($variable eq 'nks');
	if ($variable eq 'xk') {
		$result=[];
		foreach my $xk (@{$self->{xk}}) {
			push @{$result},[ map { $_->get } @{$xk} ];
		}
		return($result);
	} elsif ($variable eq 'wk') {
		return([ map { $_->get } @{$self->{wk}} ]);
	}
	return(undef);
}
sub set {
	my ($self,$variable,$value,@index)=@_;
	return(undef) unless (defined $variable);
	return(undef) unless (defined $value);
	if ($variable eq 'units') {
		if ($value =~ /^(?:automatic|gamma)$/) {
			die "cannot change units from '" . $self->get('units') . "' to '$value'";
		}
		return(undef);
	}
	my @adj;
	my $nks = $self->get('nks');
	if ($variable eq 'xk') {
		if ($#index < 0) {
			die "dimension mismatch" if ($#{$value} != $nks-1);
			for (my $i=0; $i<$nks;$i++) {
				for (my $j=0; $j<3; $j++) {
					push @adj,$self->{xk}->[$i]->[$j]->set_padded($value->[$i]->[$j]);
				}
			}
		} elsif ($#index == 0) {
			for (my $j=0;$j<3;$j++) {
				push @adj,$self->{xk}->[$index[0]]->[$j]->set_padded($value->[$j]);
			}
		} elsif ($#index == 1) {
			push @adj,$self->{xk}->[$index[0]]->[$index[1]]->set_padded($value);
		}
	} elsif ($variable eq 'wk') {
		if ($#index < 0) {
			die "dimension mismatch" if ($#{$value} != $nks-1);
			for (my $i=0; $i<$nks;$i++) {
				push @adj,$self->{wk}->[$i]->set_padded($value->[$i]);
			}
		} elsif ($#index == 0) {
			push @adj,$self->{wk}->[$index[0]]->set_padded($value);
		}
	} else {
		die "unknown variable '$variable'";
	}
	return(Fortran::Namelist::Editor::Span::summarize_adj(@adj));
}
1;
