package Fortran::Namelist::Editor::Value;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
@Fortran::Namelist::Editor::Value::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	$self->{fortran}   = substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b});
	$self->{perl}      = substr($self->{container}->{data},$self->{o_b},$self->{o_e}-$self->{o_b});
	return($self);
}
sub subclass {
	my ($container,$o_b,$o_e) = @_;
	my @opts=($container,$o_b,$o_e);
	# type detection by try-and-error
	my $obj;
	$obj=Fortran::Namelist::Editor::Value::string->new($container,$o_b,$o_e);
	return($obj) if (defined $obj);
	$obj=Fortran::Namelist::Editor::Value::integer->new($container,$o_b,$o_e);
	return($obj) if (defined $obj);
	$obj=Fortran::Namelist::Editor::Value::double->new($container,$o_b,$o_e);
	return($obj) if (defined $obj);
	$obj=Fortran::Namelist::Editor::Value::single->new($container,$o_b,$o_e);
	return($obj) if (defined $obj);
	$obj=Fortran::Namelist::Editor::Value::logical->new($container,$o_b,$o_e);
	return($obj) if (defined $obj);
	return(undef);
}
sub get {
	my $self=shift;
	return($self->{perl});
}

package Fortran::Namelist::Editor::Value::string;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::string::ISA=qw{Fortran::Namelist::Editor::Value};
sub init {
	my ($self,$container,$o_b,$o_e,$unquoted) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		return(undef) unless ($self->{fortran}=~/^['"]/);
	}
	return($self);
}

package Fortran::Namelist::Editor::Value::integer;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::integer::ISA=qw{Fortran::Namelist::Editor::Value};
sub init {
	my ($self,$container,$o_b,$o_e,$data) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		return(undef) unless ($self->{fortran}=~/^[+-]?\d+$/);
	}
	return($self);
}

package Fortran::Namelist::Editor::Value::double;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::double::ISA=qw{Fortran::Namelist::Editor::Value};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		return(undef) unless ($self->{fortran}=~m{
			(                     ## group1: mantissa
				[+-]?             ##    optional sign
				(?:\d*\.\d+       ##    with decimal point
				|
				\d+)              ##    without decimal point
			)
			[dD]([+-]?\d+)        ## group 2: exponent with optional sign
			}x);
		$self->{perl}="$1e$2";
	}
	return($self);
}

package Fortran::Namelist::Editor::Value::single;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::single::ISA=qw{Fortran::Namelist::Editor::Value};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		return(undef) unless ($self->{fortran}=~m{
			(                     ## group1: mantissa
				[+-]?             ##    optional sign
				(?:\d*(\.\d+)     ##    group 2: decimal point and digits
				|
				\d+)              ##    without decimal point
			)
			(?:[eE]([+-]?\d+))?   ## group3: exponent with optional sign
			}x);
	}
	return($self);
}

package Fortran::Namelist::Editor::Value::logical;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::logical::ISA=qw{Fortran::Namelist::Editor::Value};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		return(undef) unless ($self->{fortran}=~/^\W*([tTfF])/);
		$self->{perl} = (lc($1) eq 'f' ? 0 : 1);
	}
	return($self);
}
1;
