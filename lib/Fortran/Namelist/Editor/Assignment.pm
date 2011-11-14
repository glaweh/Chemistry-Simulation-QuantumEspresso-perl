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
sub delete {
	my $self=shift;
	my $offset_b=$self->{o_b};
	my $offset_e=$self->{o_e};
	my $length=$offset_e-$offset_b;
	my $replacement='';
	# check if there is data in the same line
	pos($self->{container}->{data_cs})=$offset_e;
	if ($self->{container}->{data_cs} =~ /\G(,[ \t]*)([^\n]*)\n/gs) {
		$length+=$+[1]-$-[1];
		$replacement="\n$self->{container}->{indent}";
	}
	# remove the string from data/data_cs
	substr($self->{container}->{data},$offset_b,$length)=$replacement;
	substr($self->{container}->{data_cs},$offset_b,$length)=$replacement;
	$self->{container}->adjust_offsets($offset_b,length($replacement)-$length);
}

1;
