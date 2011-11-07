package Chemistry::Simulation::QuantumEspresso::pw::in;
use strict;
use warnings;
use Carp;
use Fortran::Namelist::Editor;
@Chemistry::Simulation::QuantumEspresso::pw::in::ISA=('Fortran::Namelist::Editor');

sub init {
	my $self=shift;
	$self->SUPER::init(@_);
}

1;
