package Chemistry::Simulation::QuantumEspresso::pw::in;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
use Scalar::Util qw(blessed);
use Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_SPECIES;
use Chemistry::Simulation::QuantumEspresso::pw::in::card::ATOMIC_POSITIONS;
use Chemistry::Simulation::QuantumEspresso::pw::in::card::CELL_PARAMETERS;
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

1;
