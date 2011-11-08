package Fortran::Namelist::Editor::Span;
use strict;
use warnings;
sub new {
	my $class = shift;
	my $self  = {};
	bless($self,$class);
	return($self->init(@_));
}
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->{container} = $container;
	$self->{o_b}       = $o_b;
	$self->{o_e}       = $o_e;
	return($self);
}
sub _set {
	my ($self,$new_value,$new_value_cs) = @_;
	my $old_length = $self->{o_e}-$self->{o_b};
	my $new_length = length($new_value);
	substr($self->{container}->{data},$self->{o_b},$old_length)    = $new_value;
	substr($self->{container}->{data_cs},$self->{o_b},$old_length) = $new_value_cs;
	$self->{container}->adjust_offsets($self->{o_b},$new_length-$old_length) if ($new_length != $old_length);
	return(1);
}
sub set {
	my ($self,$new_value) = @_;
	return($self->_set($new_value,$new_value));
}
sub _get {
	my ($self) = @_;
	return(substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b}));
}
sub get {
	my ($self) = @_;
	return($self->_get());
}

package Fortran::Namelist::Editor::Token;
use strict;
use warnings;
@Fortran::Namelist::Editor::Token::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	$self->{perl}      = lc(substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b}));
	return($self);
}
sub set {
	my ($self,$new_value) = @_;
	$self->{perl} = lc($new_value);
	return($self->_set($new_value,$new_value));
}
sub get {
	my $self=shift;
	return($self->{perl});
}

package Fortran::Namelist::Editor::CaseSensitiveToken;
use strict;
use warnings;
@Fortran::Namelist::Editor::CaseSensitiveToken::ISA=qw{Fortran::Namelist::Editor::Span};
1;