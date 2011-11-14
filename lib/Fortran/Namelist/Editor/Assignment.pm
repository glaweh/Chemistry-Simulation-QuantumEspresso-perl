package Fortran::Namelist::Editor::Assignment;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Index;
use Fortran::Namelist::Editor::Value;
@Fortran::Namelist::Editor::Assignment::ISA = qw{Fortran::Namelist::Editor::Container};
sub init {
	my ($self,$container,$o_b,$o_e,$o_name_b,$o_name_e,$o_index_b,$o_index_e,$value)=@_;
	$self->SUPER::init($container,$o_b,$o_e);
	$self->{name}  = Fortran::Namelist::Editor::Token->new($container,$o_name_b,$o_name_e);
	$self->{index} = Fortran::Namelist::Editor::Index->new($container,$o_index_b,$o_index_e);
	$self->{value} = $value;
	return($self);
}

1;
