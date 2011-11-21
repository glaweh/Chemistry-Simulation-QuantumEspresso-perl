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

1;
