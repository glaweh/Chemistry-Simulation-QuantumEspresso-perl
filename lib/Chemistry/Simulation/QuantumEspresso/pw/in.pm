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
			$i=$self->_parse_atomic_species(\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*atomic_positions/i) {
			$i=$self->_parse_atomic_positions(\@lines,\@lines_cs,\@o_lines,$i);
		}
	} continue {
		if (defined $card) {
			push @{$self->{_cards}},$card;
			$self->{cards}->{$card->{name}}=$card;
			$card=undef;
		}
		$i++;
	}
}

sub _parse_atomic_species {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	my %card = (
		name     => 'atomic_species',
		o_b      => $o_lines->[$i],
		o_e      => undef,
		species  => {},
		_species => [ undef ],        # fortran counts from 1, so leave 0 empty
	);
	my $ntyp=$self->{groups}->{system}->{vars}->{ntyp}->{value};
	while ($#{$card{_species}} < $ntyp) {
		$i++;
		next if ($lines_cs->[$i] =~ /^\s*$/);
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s*(\S+)\s*(\S+)/) {
			my %species=(
				label               => $1,
				mass                => $2,
				pseudopotential     => $3,
				o_label_b           => $-[1],
				o_label_e           => $+[1],
				o_mass_b            => $-[2],
				o_mass_e            => $+[2],
				o_pseudopotential_b => $-[3],
				o_pseudopotential_e => $+[3],
			);
			Fortran::Namelist::Editor::adjust_offsets(\%species,0,$o_lines->[$i]);
			$card{species}->{$species{label}}=\%species;
			push @{$card{_species}},\%species;
		}
	}
	$card{o_e}=$o_lines->[$i+1]-1;
	push @{$self->{_cards}},\%card;
	$self->{cards}->{$card{name}}=\%card;
	return($i);
}

sub _parse_atomic_positions {
	my ($self,$lines,$lines_cs,$o_lines,$i) = @_;
	my %card = (
		name      => 'atomic_positions',
		o_b       => $o_lines->[$i],
		o_e       => undef,
		units     => 'alat',
		o_units_b => undef,
		o_units_e => undef,
		atom      => {},
		_atom     => [ undef ],        # fortran counts from 1, so leave 0 empty
	);
	# check for units
	my $title = $lines_cs->[$i];
	while ($title =~ /__+/) {
		substr($title,$-[0],$+[0]-$-[0])=substr($lines->[$i],$-[0],$+[0]-$-[0]);
	}
	if ($title =~ /^\s*atomic_positions\s+\S*(alat|bohr|angstrom|crystal)\S*/i) {
		$card{units}=lc($1);
	}
	my $nat=$self->{groups}->{system}->{vars}->{nat}->{value};
	while ($#{$card{_atom}} < $nat) {
		$i++;
		last if ($i > $#{$lines});
		next if ($lines_cs->[$i] =~ /^\s*$/);
		if ($lines_cs->[$i] =~ /^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(\S+)\s+(\S+)\s+(\S+))?/) {
			my %atom=(
				species             => $1,
				position            => [ $2, $3, $4 ],
				o_position_b        => [ $-[2], $-[3], $-[4] ],
				p_position_e        => [ $+[2], $+[3], $+[4] ],
				if_pos              => [ $5, $6, $7 ],
				o_if_pos_b          => [ $-[5], $-[6], $-[7] ],
				p_if_pos_e          => [ $+[5], $+[6], $+[7] ],
				o_b                 => $o_lines->[$i],
				o_e                 => $o_lines->[$i+1]-1,
			);
			Fortran::Namelist::Editor::adjust_offsets(\%atom,0,$o_lines->[$i]);
			push @{$card{atom}->{$atom{species}}},\%atom;
			push @{$card{_atom}},\%atom;
		}
	}
	$card{o_e}=$o_lines->[$i+1]-1;
	push @{$self->{_cards}},\%card;
	$self->{cards}->{$card{name}}=\%card;
	return($i);
}

1;
