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
	return(undef,$self) if (wantarray);
	return($self);
}

sub parse {
	my ($class,$namelist,$lines,$lines_cs,$o_lines,$i) = @_;
	my $title = $lines_cs->[$i];
	while ($title =~ /__+/) {
		substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
	}
	my $o_line = $o_lines->[$i];
	my $self;
	if ($title =~ /^\s*(K_POINTS)(?:\s+\S*(tpiba|automatic|crystal|gamma|tpiba_b|crystal_b)\S*)?/i) {
		my $name  = Fortran::Namelist::Editor::CaseSensitiveToken->new($namelist,$-[1]+$o_line,$+[1]+$o_line);
		my ($units,$units_o);
		if (defined $2) {
			$units=lc($2);
			$units_o=Fortran::Namelist::Editor::Token->new($namelist,$-[2]+$o_line,$+[2]+$o_line);
		} else {
			$units=$units_o='tpiba';
		}
		# check for units
		if ($class =~ /K_POINTS$/) {
			if ((defined $units) and ($units eq 'gamma')) {
				$class.='::gamma';
			} elsif ((defined $units) and ($units eq 'automatic')) {
				$class.='::automatic';
			} else {
				$class.='::list';
			}
		}
		$self=$class->new($namelist);
		$self->{_o}->[0] = $o_line;
		$self->{name}=$name;
		$self->{units}=$units_o;
		$self->{_o}->[1] = $lines->[$i+1];
	} else {
		die "Error parsing K_POINTS title";
	}
	return($self->_parse_subclass($lines,$lines_cs,$o_lines,$i+1));
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

sub _parse_subclass {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	return($i,$self);
}

sub get {
	my ($self,$variable,@index)=@_;
	unless (defined $variable) {
		my $h;
		$h->{units} = $self->_get_units();
		return($h);
	}
	return($self->_get_units()) if ($variable eq 'units');
	return(undef);
}

sub insert {
	my ($class,$namelist,$o_b,$separator,$name,$units,@args) = @_;
	die "units option undefined" unless (defined $units);
	if ($units eq 'gamma') {
		$class = 'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma';
	} elsif ($units eq 'automatic') {
		$class = 'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::automatic';
	} else {
		$class = 'Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::list';
	}
	my $self = $class->new($namelist);
	$self->{_o}->[0] = $o_b;
	$self->{_o}->[1] = $o_b;
	$self->{name}    = Fortran::Namelist::Editor::CaseSensitiveToken->insert($namelist,$o_b,$separator,$name);
	$self->{units}   = Fortran::Namelist::Editor::Token->insert($namelist,$self->{name}->{_o}->[1],' ',$units);
	$self->{_o}->[1] = $self->{units}->{_o}->[1];

	return($self->_insert_subclass(@args));
}

sub _insert_subclass {
	return(undef);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS::gamma::ISA =
	qw{Chemistry::Simulation::QuantumEspresso::pw::in::card::K_POINTS};
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
sub _parse_subclass {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	while (1) {
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s(\s*\S+)\s(\s*\S+)\s(\s*\S+)\s(\s*\S+)\s(\s*\S+)/) {
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
		$i++;
	}
	$self->{_o}->[1]=$o_lines->[$i+1];
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
	if (($variable eq 'nk') or ($variable eq 'sk')) {
		if ($#index < 0) {
			for (my $i=0; $i<3; $i++) {
				$self->{$variable}->[$i]->set_padded($value->[$i]);
			}
		} else {
			$self->{$variable}->[$index[0]]->set_padded($value);
		}
	} else {
		die "unknown variable '$variable'";
	}
	return(1);
}
sub _insert_subclass {
	my ($self,@grid) = @_;
	map { $grid[$_] = 1 unless (defined $grid[$_]) } 0 .. 2;
	map { $grid[$_] = 0 unless (defined $grid[$_]) } 3 .. 5;
	my $to_insert = sprintf("\n%s%2d %2d %2d %2d %2d %2d",$self->{_namelist}->{indent},@grid);
	my @length = map { my $l=length($_); $l=2 if ($l<2); $l } @grid;
	my $offset=$self->{_namelist}->refine_offset_forward($self->{_o}->[1],qr{([^\n]+)}s);
	my $delta =$self->{_namelist}->set_data($offset,$offset,$to_insert);
	$self->{_o}->[1] += $delta;
	$offset+=length($self->{_namelist}->{indent})+1;
	for (my $i=0;$i<3;$i++) {
		push @{$self->{nk}},Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$offset,$offset+$length[$i]);
		$offset+=$length[$i]+1;
	}
	for (my $i=3;$i<6;$i++) {
		push @{$self->{sk}},Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$offset,$offset+$length[$i]);
		$offset+=$length[$i]+1;
	}
	return($self)
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
sub _parse_subclass {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	my $nks;
	while (1) {
		last if ((defined $nks) and ($#{$self->{k}} >= $nks-1));
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s*$/) {
			$self->{nks}=Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
			$nks=$self->{nks}->get;
			$i++;
			next;
		}
		if ($lines_cs->[$i] =~ /^\s?(\s*\S+)\s(\s*\S+)\s(\s*\S+)\s(\s*\S+)/) {
			push @{$self->{xk}},[
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			];
			push @{$self->{wk}},
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[4],$o_line+$+[4]);
		}
		$i++;
	}
	$self->{_o}->[1]=$o_lines->[$i];
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
			die "cannot change units from '" . $self->_get_units() . "' to '$value'";
		}
		return($self->_set_units($value));
	}
	my $nks = $self->get('nks');
	if ($variable eq 'xk') {
		if ($#index < 0) {
			die "dimension mismatch" if ($#{$value} != $nks-1);
			for (my $i=0; $i<$nks;$i++) {
				for (my $j=0; $j<3; $j++) {
					$self->{xk}->[$i]->[$j]->set_padded($value->[$i]->[$j]);
				}
			}
		} elsif ($#index == 0) {
			for (my $j=0;$j<3;$j++) {
				$self->{xk}->[$index[0]]->[$j]->set_padded($value->[$j]);
			}
		} elsif ($#index == 1) {
			$self->{xk}->[$index[0]]->[$index[1]]->set_padded($value);
		}
	} elsif ($variable eq 'wk') {
		if ($#index < 0) {
			die "dimension mismatch" if ($#{$value} != $nks-1);
			for (my $i=0; $i<$nks;$i++) {
				$self->{wk}->[$i]->set_padded($value->[$i]);
			}
		} elsif ($#index == 0) {
			$self->{wk}->[$index[0]]->set_padded($value);
		}
	} else {
		die "unknown variable '$variable'";
	}
	return(1);
}
sub _insert_subclass {
	my ($self,$xk,$wk) = @_;
	die "needs xk array ref" unless (ref $xk eq 'ARRAY');
	my @wk  = @{$wk} if (ref $wk eq 'ARRAY');
	map { $wk[$_] = 1 unless (defined $wk[$_]) } 0 .. $#{$xk};
	# calculate insertion
	my $nks = $#{$xk}+1;
	my $nindent = "\n" . $self->{_namelist}->{indent};
	my $lindent = length($nindent);
	my $to_insert = sprintf("%s%4d",$nindent,$nks);
	my $o_b=$self->{_namelist}->refine_offset_forward($self->{_o}->[1],qr{([^\n]+)}s);
	my $offset = $o_b+$lindent;
	my @nks_o = ($offset, $offset+4);
	$offset+=4;
	my (@xk_o,@wk_o);
	for (my $i=0;$i<=$#{$xk};$i++) {
		$to_insert.=sprintf("%s%14.10f %14.10f %14.10f %s",$nindent,@{$xk->[$i]},$wk[$i]);
		$offset+=$lindent;
		my @length = map { my $l=length($_); $l=14 if ($l < 14) } @{$xk->[$i]};
		for (my $j=0;$j<3;$j++) {
			push @{$xk_o[$i]},[$offset,$offset+$length[$j]];
			$offset+=$length[$j]+1;
		}
		push @wk_o,[$offset,$offset+length($wk[$i])];
		$offset+=length($wk[$i]);
	}
	$self->{_namelist}->set_data($o_b,$o_b,$to_insert);
	$self->{nks} = Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},@nks_o);
	for (my $i=0;$i<=$#{$xk};$i++) {
		push @{$self->{xk}},[
			map { 
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},@{$_})
			} @{$xk_o[$i]} ];
		push @{$self->{wk}},Fortran::Namelist::Editor::Value::single->new($self->{_namelist},@{$wk_o[$i]});
	}
	$self->{_o}->[1] += length($to_insert);
	return($self)
}
1;
