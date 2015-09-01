package Chemistry::Simulation::QuantumEspresso::IN::pw::card;
use strict;
use warnings;
@Chemistry::Simulation::QuantumEspresso::IN::pw::card::ISA=qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist,$lines,$lines_cs,$o_lines,$i)=@_;
	my $o_line=$o_lines->[$i] if (defined $i);
	$self->SUPER::init($namelist,$o_line);
	$self->{name}      = undef;
	push @{$self->{_get_ignore_patterns}},qr/^name$/;
	return($i,$self);
}

sub parse {
	my ($class,$namelist,$lines,$lines_cs,$o_lines,$i) = @_;
	my $self = $class->new($namelist);
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

1;
