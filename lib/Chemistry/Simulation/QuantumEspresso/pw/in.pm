package Chemistry::Simulation::QuantumEspresso::pw::in;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
use Scalar::Util qw(blessed);
use Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_SPECIES;
use Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_POSITIONS;
@Chemistry::Simulation::QuantumEspresso::pw::in::ISA=('Fortran::Namelist::Editor');
my @groups = qw{&control &system &electrons &ions &cell ATOMIC_SPECIES ATOMIC_POSITIONS K_POINTS CELL_PARAMETERS OCCUPATIONS CONSTRAINTS};
my %groups = map { $groups[$_],$_ } 0 .. $#groups;

sub init {
	my $self=shift;
	$self->SUPER::init(@_);
	$self->parse_cards;
	return($self);
}

sub parse_cards {
	my $self=shift;
	# cards are between end of last group and end of file
	my $o_cards=$self->{_groups}->[-1]->{o_e};
	my ($data,$data_cs) = $self->get_data($o_cards,$self->{o_e});
	# cards can be worked on line-by-line
	my @lines_cs = map { "$_\n" } split('\n',$data_cs);
	my @lines;
	my @o_lines  = (0);
	foreach my $line_cs (@lines_cs) {
		push @lines,substr($data,$o_lines[-1],length($line_cs));
		push @o_lines,$o_lines[-1]+length($line_cs);
	}
	map { $_+=$o_cards } @o_lines;
	my $i=0;
	my $card;
	while ($i<=$#lines) {
		# skip empty lines
		next if ($lines_cs[$i] =~ /^\s*$/) ;
		if ($lines_cs[$i] =~ /^\s*ATOMIC_SPECIES/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_SPECIES->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*ATOMIC_POSITIONS/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_POSITIONS->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*CELL_PARAMETERS/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
	} continue {
		if (defined $card) {
			push @{$self->{_groups}},$card;
			$self->{groups}->{$card->name}=$card;
			$card=undef;
		} else {
			$i++;
		}
	}
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::ISA=qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist,$lines,$lines_cs,$o_lines,$i)=@_;
	$self->SUPER::init($namelist,$o_lines->[$i]);
	$self->{name}      = undef;
	push @{$self->{_get_ignore_patterns}},qr/^name$/;
	return($i,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	return($i,$self);
}

sub name {
	my $self=shift;
	my $name;
	if (defined $self->{name}) {
		eval { $name=$self->{name}->get; };
		$name=$self->{name} unless (defined $name);
		return($name);
	}
	return($name);
}

sub set {
	die "unimplemented";
}

sub get {
	die "unimplemented";
}


package Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}     ='CELL_PARAMETERS';
	$self->{symmetry} = undef;
	$self->{v}        = [];
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
	if ($title =~ /^\s*(CELL_PARAMETERS)(?:\s+\S*(cubic|hexagonal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{name}=Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{symmetry}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
		} else {
			substr($lines->[$i],$+[1],0) = ' cubic';
			substr($lines_cs->[$i],$+[1],0) = ' cubic';
			foreach (@{$o_lines}) {
				$_+=6 if ($_ > $o_line);
			}
			my $adj;
			($self->{symmetry},$adj)=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','cubic');
			$self->_adjust_offsets($adj);
		}
	}

	while (1) {
		$i++;
		last if ($#{$self->{v}} >= 2);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)/) {
			my $vec = [
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{_namelist},$o_line+$-[3],$o_line+$+[3]),
			];
			push @{$self->{v}},$vec;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{v}} < 2) {
		warn "Card 'CELL_PARAMETERS' incomplete";
	}
	return($i,$self);
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
		return($h);
	} else {
		if ($var eq 'symmetry') {
			return($self->{symmetry}->get);
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
		return($self->{symmetry}->set($value));
	} elsif ($var eq 'v') {
		return($self->_set_vec($value,@index));
	}
}
1;
