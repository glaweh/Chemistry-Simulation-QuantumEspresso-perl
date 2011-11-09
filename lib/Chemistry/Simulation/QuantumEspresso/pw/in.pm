package Chemistry::Simulation::QuantumEspresso::pw::in;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
@Chemistry::Simulation::QuantumEspresso::pw::in::ISA=('Fortran::Namelist::Editor');

sub init {
	my $self=shift;
	$self->SUPER::init(@_);
	$self->{_cards}=[];
	$self->{cards}={};
	$self->parse_cards;
	return(1);
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
			$self->{cards}->{$card->{name}}=$card;
			$card=undef;
		} else {
			$i++;
		}
	}
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::ISA=qw{Fortran::Namelist::Editor::Container};
sub init {
	my ($self,$container,$lines,$lines_cs,$o_lines,$i)=@_;
	$self->SUPER::init($container,$o_lines->[$i]);
	$self->{name}      = undef;
	return($i,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	return($i,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_species;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_species::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$container,@args)=@_;
	$self->SUPER::init($container,@args);
	$self->{name}='atomic_species';
	$self->{species}  = {};
	$self->{_species} = [ undef ]; # fortran counts from 1, so leave 0 empty
	if ($#args >= 0) {
		return($self->parse(@args));
	}
	return(undef,$self);
}

sub parse {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	$self->{o_b} = $o_lines->[$i];
	my $ntyp=$self->{container}->{groups}->{system}->{vars}->{ntyp}->{value};
	while (1) {
		$i++;
		last if ($#{$self->{_species}} >= $ntyp);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)/) {
			my $species=Fortran::Namelist::Editor::Container->new($self->{container},$o_line,$o_lines->[$i+1]-1);
			$species->{label}           = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
			$species->{mass}            = Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[2],$o_line+$+[2]);
			$species->{pseudopotential} = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{container},$o_line+$-[3],$o_line+$+[3]);
			$self->{species}->{$species->{label}->get}=$species;
			push @{$self->{_species}},$species;
		} else {
			last;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{_species}} < $ntyp) {
		warn "Card 'atomic_species' incomplete";
	}
	return($i,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_positions;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::atomic_positions::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$container,@args)=@_;
	$self->SUPER::init($container,@args);
	$self->{name}  ='atomic_positions';
	$self->{units} = undef;
	$self->{atom}  = {};
	$self->{_atom} = [ undef ]; # fortran counts from 1, so leave 0 empty
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
		$self->{name}=Fortran::Namelist::Editor::Token->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{units}=Fortran::Namelist::Editor::Token->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
		} else {
			substr($lines->[$i],$+[1],0) = ' alat';
			substr($lines_cs->[$i],$+[1],0) = ' alat';
			foreach (@{$o_lines}) {
				$_+=5 if ($_ > $o_line);
			}
			$self->{units}=Fortran::Namelist::Editor::Token->insert($self->{container},$o_line+$+[1],'alat');
		}
	}

	my $nat=$self->{container}->{groups}->{system}->{vars}->{nat}->{value};
	while (1) {
		$i++;
		last if ($#{$self->{_atom}} >= $nat);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+)\s+(\S+)\s+(\S+))?/) {
			warn 'da';
			my $atom=Fortran::Namelist::Editor::Container->new($self->{container},$o_line,$o_lines->[$i+1]-1);
			$atom->{species}         = Fortran::Namelist::Editor::CaseSensitiveToken->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
			@{$atom->{position}}     = [
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[3],$o_line+$+[3]),
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[4],$o_line+$+[4]),
			];
			if (defined $5) {
				@{$atom->{if_pos}}     = [
					Fortran::Namelist::Editor::Value::integer->new($self->{container},$o_line+$-[5],$o_line+$+[5]),
					Fortran::Namelist::Editor::Value::integer->new($self->{container},$o_line+$-[6],$o_line+$+[6]),
					Fortran::Namelist::Editor::Value::integer->new($self->{container},$o_line+$-[7],$o_line+$+[7]),
				];
			}
			push @{$self->{_atom}},$atom;
		}
	}
	$self->{o_e}=$o_lines->[$i];
	if ($#{$self->{_atom}} < $nat) {
		warn "Card 'atomic_positions' incomplete";
	}
	return($i,$self);
}

package Chemistry::Simulation::QuantumEspresso::pw::in::card::cell_parameters;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::pw::in::card::cell_parameters::ISA = qw{Chemistry::Simulation::QuantumEspresso::pw::in::card};
sub init {
	my ($self,$container,@args)=@_;
	$self->SUPER::init($container,@args);
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
	if ($title =~ /^\s*(cell_parameters)(\s+\S*(cubic|hexagonal)\S*)?/i) {
		my $o_line = $o_lines->[$i];
		$self->{name}=Fortran::Namelist::Editor::Token->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
		if (defined $2) {
			$self->{symmetry}=Fortran::Namelist::Editor::Token->new($self->{container},$o_line+$-[1],$o_line+$+[1]);
		} else {
			substr($lines->[$i],$+[1],0) = ' cubic';
			substr($lines_cs->[$i],$+[1],0) = ' cubic';
			foreach (@{$o_lines}) {
				$_+=6 if ($_ > $o_line);
			}
			$self->{symmetry}=Fortran::Namelist::Editor::Token->insert($self->{container},$o_line+$+[1],'cubic');
		}
	}

	while (1) {
		$i++;
		last if ($#{$self->{v}} >= 2);
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		my $o_line = $o_lines->[$i];
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)/) {
			warn 'da';
			my $vec = [
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[1],$o_line+$+[1]),
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[2],$o_line+$+[2]),
				Fortran::Namelist::Editor::Value::single->new($self->{container},$o_line+$-[3],$o_line+$+[3]),
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
1;
