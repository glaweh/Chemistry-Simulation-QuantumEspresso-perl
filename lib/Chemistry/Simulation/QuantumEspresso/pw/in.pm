package Chemistry::Simulation::QuantumEspresso::pw::in;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
use Scalar::Util qw(blessed);
@Chemistry::Simulation::QuantumEspresso::pw::in::ISA=('Fortran::Namelist::Editor');

sub init {
	my $self=shift;
	$self->SUPER::init(@_);
	$self->{_cards}=[];
	$self->{cards}={};
	$self->parse_cards;
	return($self);
}

sub parse_cards {
	my $self=shift;
	return(2) unless ($#{$self->{_groupless}} >= 0);
	my $o_cards=$self->{_groupless}->[0]->{o_b};
	# cards can be worked on line-by-line
	my @lines_cs = map { "$_\n" } split('\n',substr($self->{data},$o_cards,$self->{_groupless}->[0]->{o_e}-$o_cards));
	my $offset_c = $o_cards;
	my @o_lines  = map { my $o_line_b = $offset_c; $offset_c+=length($_); $o_line_b } @lines_cs;
	push @o_lines,$self->{_groupless}->[0]->{o_e};
	my @lines    = map { substr($self->{data},$o_lines[$_],$o_lines[$_+1]-$o_lines[$_]) } 0 .. $#lines_cs;
	my $i=0;
	my $card;
	while ($i<=$#lines) {
		# skip empty lines
		next if ($lines_cs[$i] =~ /^\s*$/) ;
		if ($lines_cs[$i] =~ /^\s*atomic_species/i) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_species->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*atomic_positions/i) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_positions->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*cell_parameters/i) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::pw::in::card::cell_parameters->new($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
	} continue {
		if (defined $card) {
			push @{$self->{_cards}},$card;
			$self->{cards}->{$card->name}=$card;
			$card=undef;
		} else {
			$i++;
		}
	}
}

sub as_hash {
	my ($self)=@_;
	my $h=$self->SUPER::as_hash;
	foreach my $card (keys %{$self->{cards}}) {
		next unless (blessed($self->{cards}->{$card}) and $self->{cards}->{$card}->can('get'));
		$h->{$card}=$self->{cards}->{$card}->get;
	}
	return($h);
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

package Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_species;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_species::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}='atomic_species';
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
	if ($lines_cs->[$i] =~ /^\s*(atomic_species)/i) {
		$self->{name}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
	}
	my $ntyp=$self->{_namelist}->{groups}->{system}->{vars}->{ntyp}->{value}->get;
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
		warn "Card 'atomic_species' incomplete";
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

package Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_positions;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_positions::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}  ='atomic_positions';
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
	if ($title =~ /^\s*(atomic_positions)(\s+\S*(alat|bohr|angstrom|crystal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{name}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{units}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		} else {
			substr($lines->[$i],$+[1],0) = ' alat';
			substr($lines_cs->[$i],$+[1],0) = ' alat';
			foreach (@{$o_lines}) {
				$_+=5 if ($_ > $o_line);
			}
			$self->{units}=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','alat');
		}
	}

	my $nat=$self->{_namelist}->{groups}->{system}->{vars}->{nat}->{value}->get;
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
		warn "Card 'atomic_positions' incomplete";
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

package Chemistry::Simulation::QuantumEspresso::pw::in::card::cell_parameters;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::cell_parameters::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$namelist,@args)=@_;
	$self->SUPER::init($namelist,@args);
	$self->{name}     ='cell_parameters';
	$self->{symmetry} = undef;
	$self->{v}     = [];
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
	if ($title =~ /^\s*(cell_parameters)(?:\s+\S*(cubic|hexagonal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{name}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{symmetry}=Fortran::Namelist::Editor::Token->new($self->{_namelist},$o_line+$-[2],$o_line+$+[2]);
		} else {
			substr($lines->[$i],$+[1],0) = ' cubic';
			substr($lines_cs->[$i],$+[1],0) = ' cubic';
			foreach (@{$o_lines}) {
				$_+=6 if ($_ > $o_line);
			}
			$self->{symmetry}=Fortran::Namelist::Editor::Token->insert($self->{_namelist},$o_line+$+[1],' ','cubic');
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
		warn "Card 'cell_parameters' incomplete";
	}
	return($i,$self);
}

sub get {
	my $self = shift;
	my $h = $self->SUPER::get();
	for my $vec (@{$self->{v}}) {
		push @{$h->{v}}, [ map { $_->get } @{$vec} ];
	}
	return($h);
}
1;
