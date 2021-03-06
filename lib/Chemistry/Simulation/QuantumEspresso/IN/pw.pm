package Chemistry::Simulation::QuantumEspresso::IN::pw;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
use Scalar::Util qw(blessed);
use Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_SPECIES;
use Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_POSITIONS;
use Chemistry::Simulation::QuantumEspresso::IN::pw::card::CELL_PARAMETERS;
use Chemistry::Simulation::QuantumEspresso::IN::pw::card::K_POINTS;
@Chemistry::Simulation::QuantumEspresso::IN::pw::ISA=('Fortran::Namelist::Editor');
my @groups = qw{&control &system &electrons &ions &cell ATOMIC_SPECIES ATOMIC_POSITIONS K_POINTS CELL_PARAMETERS OCCUPATIONS CONSTRAINTS};
my %groups = map { $groups[$_],$_ } 0 .. $#groups;

sub parse_data {
	my $self=shift;
	my $r=$self->SUPER::parse_data;
	die "Fortran::Namelist::Editor->parse_data(" . join(',',@_) . ") failed" unless ($r);
	$self->parse_cards;
	return($self);
}

sub parse_cards {
	my $self=shift;
	# cards are between end of last group and end of file
	my $o_cards;
	if ($#{$self->{_groups}} >= 0) {
		$o_cards=$self->{_groups}->[-1]->{_o}->[1] if ($#{$self->{_groups}} >= 0);
	} else {
		warn "No groups found, start parsing cards at beginning of data";
		$o_cards=$self->{_o}->[0];
	}

	my ($data,$data_cs) = $self->get_data($o_cards,$self->{_o}->[1]);
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
			($i,$card)=Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_SPECIES->parse($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*ATOMIC_POSITIONS/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::IN::pw::card::ATOMIC_POSITIONS->parse($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*CELL_PARAMETERS/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::IN::pw::card::CELL_PARAMETERS->parse($self,\@lines,\@lines_cs,\@o_lines,$i);
			next;
		}
		if ($lines_cs[$i] =~ /^\s*K_POINTS/) {
			($i,$card)=Chemistry::Simulation::QuantumEspresso::IN::pw::card::K_POINTS->parse($self,\@lines,\@lines_cs,\@o_lines,$i);
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
sub add_group {
	my ($self,$group_name,$after,@options)=@_;
	die "no group name" unless $group_name;
	my $is_card = ($group_name !~ /^&/);
	$group_name=lc($group_name) unless ($is_card);
	die "unknown group name: '$group_name'" unless (exists $groups{$group_name});
	return(2) if (exists $self->{groups}->{$group_name});
	# find position
	my $new_order     = $groups{$group_name};
	my $after_idx     = $#{$self->{_groups}};
	my @present_order = map { $groups{$_->{name}->get()} } @{$self->{_groups}};
	for (my $i=0; $i<$#present_order; $i++) {
		if (($new_order > $present_order[$i]) and ($new_order < $present_order[$i+1])) {
			$after_idx = $i;
			last;
		}
	}
	return($self->SUPER::add_group($group_name,$after_idx,@options)) unless ($is_card);
	my $offset_b    = $self->{_groups}->[$after_idx]->{_o}->[1];
	$offset_b = $self->insert_new_line_after($offset_b,'');
	my $class = 'Chemistry::Simulation::QuantumEspresso::IN::pw::card::' . $group_name;
	my $card  = $class->insert($self,$offset_b,'',$group_name,@options);
	splice(@{$self->{_groups}},$after_idx+1,0,$card);
	$self->{groups}->{$group_name}=$card;
}

1;
