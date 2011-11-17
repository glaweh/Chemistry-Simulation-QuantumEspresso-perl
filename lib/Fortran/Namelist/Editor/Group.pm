package Fortran::Namelist::Editor::Group;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Assignment;
@Fortran::Namelist::Editor::Group::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist,$o_b,$o_e,@options) = @_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	$self->{vars} = {};
	if ($#options == 1) {
		$self->{name} = Fortran::Namelist::Editor::Token->new($namelist,$options[0],$options[1]);
	} elsif ($#options == 0) {
		$self->{name} = $options[0];
	} else {
		die "unknown option type";
	}
	$self->find_vars;
	return($self);
}
sub find_vars {
	my ($self)=@_;
	my $offset_b = $self->{name}->{o_e};
	my $offset_e = $self->{o_e}-1;
	my (undef,$data_n) = $self->{_namelist}->get_data($offset_b,$offset_e);
	my @offsets;
	# scan data_n for variables: name, optionally index, followed by '='
	while ($data_n=~m{,?\s+         ## variable assignments are separated by whitespace, optionally with a preceeding comma
			([a-zA-Z][^\(\s]+)      ## a fortran identifier starts with a letter
			\s*((?:\([^\)]*\)\s*?)*)## there may be more than one index statement attached to each variable
			\s*=\s*                 ## = separates variable and value, maybe enclosed by whitespace
		}gsx) {
		if ($#offsets>=0) {
			$offsets[-1]->[1]=$offsets[-1]->[7]=$-[0]+$offset_b;
		}
		push @offsets,[$-[1]+$offset_b,undef,
			$-[1]+$offset_b,$+[1]+$offset_b,
			$-[2]+$offset_b,$+[2]+$offset_b,
			$+[0]+$offset_b,undef];
	}
	if ($data_n =~ /\s+$/gs) {
		$offset_e-=$+[0]-$-[0];
	}
	$offsets[-1]->[1]=$offsets[-1]->[7]=$offset_e if ($#offsets>=0);
	for (my $i=0; $i<=$#offsets; $i++) {
		my @offset=@{$offsets[$i]};
		my $assignment=Fortran::Namelist::Editor::Assignment->new($self->{_namelist},@offset);
		my $name = $assignment->{name}->get;
		$self->{vars}->{$name}=Fortran::Namelist::Editor::Variable->new($self->{_namelist}) unless exists ($self->{vars}->{$name});
		$self->{vars}->{$name}->add_instance($assignment);
	}
	return(1);
}
sub get {
	my ($self,$variable,@index) = @_;
	return($self->SUPER::get) unless (defined $variable);
	return(undef) unless (exists $self->{vars}->{$variable});
	return($self->{vars}->{$variable}->get(@index));
}
sub set {
	my ($self,$variable,$value,@index) = @_;
	if (exists $self->{vars}->{$variable}) {
		return($self->{vars}->{$variable}->set($value,@index));
	}
	# insert at end of group's data section
	my $offset_b=$self->{_namelist}->refine_offset_back($self->{o_e},qr{(\n[^\n]*)/});
	$self->{vars}->{$variable} = Fortran::Namelist::Editor::Variable->insert(
		$self->{_namelist},$offset_b,"\n$self->{_namelist}->{indent}",$variable,$value,@index);
	return(1);
}
sub unset {
	my ($self,$variable,@index) = @_;
	return(0) unless (exists $self->{vars}->{$variable});
	delete ($self->{vars}->{$variable}) if ($self->{vars}->{$variable}->delete(@index));
	return(1);
}
sub indent_histogram {
	my ($self,$hist) = @_;
	my $data = $self->{_namelist}->get_data($self->{o_b},$self->{o_e});
	while ($data =~ m{\n([ \t]*)[^/\s]}gs) {
		$hist->{$1}++;
	}
	return($hist);
}
1;
