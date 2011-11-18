package Fortran::Namelist::Editor::Index;
use strict;
use warnings;
use Fortran::Namelist::Editor::Value;
@Fortran::Namelist::Editor::Index::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};

our $BASE=1;

sub init {
	my ($self,$namelist,$o_b,$o_e)=@_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	$self->{element}=[];
	return(undef) unless ($self->length > 0);
	return($self->parse);
}

sub parse {
	my $self=shift;
	my $data=$self->_get_raw();
	return(undef) if ($data=~m{^\s*$}); # no index
	# remove enclosing brackets
	if ((my $nbrackets = ($data =~ s{\(([^\)]+)\)}{ $1 }g)) != 1) {
		if ($nbrackets == 0) {
			warn "No enclosing brackets in '$data'";
		} else {
			die "Subindexing is not supported '" . $self->SUPER::get() . "'";
		}
		return(undef);
	}
	# insert a comma into each group of spaces unless there is already one
	# commas are optional in namelists, this will make it easier to parse
	$data =~ s{
		([^\s,:])       # last char of a group of non-comma, non-colon, non-space chars
		\s              # a space, to be substituted by a comma
		(\s*[^\s,:])    # first char of the next group of non-comma, non-colon, non-space chars
		}{$1,$2}gsx;
	if ($data =~ m{
			(\d+)?\s*(:)\s*(\d+)?(?:\s*:\s*(\d+))?  ## if90 docs: [subscript] : [subscript] [: stride]
		}xs) {
		die "Only explicit indexing is supported: '$data'";
	}
	if ($data !~ m{^[\s\d,]+$}) {
		die "Don't know how to parse '$data'";
	}
	while ($data=~m{(\d+)}gxs) {
		push @{$self->{element}},Fortran::Namelist::Editor::Value::integer->new($self->{_namelist},$-[1]+$self->{o_b},$+[1]+$self->{o_b});
	}
	return($self);
}

sub set {
	my ($self,@index)=@_;
	$self->{element}=[];
	my $adj=$self->SUPER::set(index2fortranstring(@index));
	$self->parse;
	return($adj);
}

sub get {
	my $self = shift;
	my @result = map { $_->get-$BASE } @{$self->{element}};
	if (wantarray) {
		return(@result);
	} else {
		return(index2perlrefstring(@result));
	}
}

sub is_equal {
	my ($self,@index) = @_;
	return(0) if ($#{$self->{element}} != $#index);
	my @elements=$self->get;
	for (my $i=0;$i<=$#index;$i++) {
		return(0) if ($index[$i] != $elements[$i]);
	}
	return(1);
}

sub insert {
	my ($class,$namelist,$o_b,$separator,@index) = @_;
	return(undef) if ($#index < 0);
	my $i = Fortran::Namelist::Editor::Span->insert($namelist,$o_b,$separator,index2fortranstring(@index));
	return($class->new($namelist,$i->{o_b},$i->{o_e}));
}

sub index2fortranstring {
	my @index = @_;
	if ($#index >=0) {
		return('(' . join(',',map { $_+$BASE } @index) . ')');
	} else {
		return('');
	}
}

sub index2perlrefstring {
	my @index = @_;
	if ($#index >=0) {
		return(join('',map { "->[$_]" } @index));
	} else {
		return('');
	}
}
1;
