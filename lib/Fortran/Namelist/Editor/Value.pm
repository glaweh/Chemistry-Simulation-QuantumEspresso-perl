package Fortran::Namelist::Editor::Value;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
@Fortran::Namelist::Editor::Value::ISA=qw{Fortran::Namelist::Editor::Span};
sub init {
	my ($self,$container,$o_b,$o_e) = @_;
	$self->SUPER::init($container,$o_b,$o_e);
	if ($o_e-$o_b>0) {
		# try to parse the string
		return(undef) unless (defined $self->get);
	}
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

package Fortran::Namelist::Editor::Value::string;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::string::ISA=qw{Fortran::Namelist::Editor::Value};
sub get {
	my $self=shift;
	my $val=$self->SUPER::get;
	if ($val =~ s/^'(.*)'$/$1/) {
		$val =~ s/''/'/g;
	} elsif ($val =~ s/^"(.*)"$/$1/) {
		$val =~ s/""/"/g;
	}
	return($val);
}
sub set {
	my ($self,$value)=@_;
	$value =~ s/'/''/g;
	$value = "'$value'";
	return($self->SUPER::set($value));
}

package Fortran::Namelist::Editor::Value::integer;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::integer::ISA=qw{Fortran::Namelist::Editor::Value};
sub get {
	my $self=shift;
	my $value=$self->SUPER::get;
	return(undef) unless ($value=~/^[+-]?\d+$/);
	return($value);
}

package Fortran::Namelist::Editor::Value::double;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::double::ISA=qw{Fortran::Namelist::Editor::Value};
sub get {
	my $self=shift;
	my $value=$self->SUPER::get;
	return(undef) unless ($value=~m{
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*\.\d+       ##    with decimal point
			|
			\d+)              ##    without decimal point
		)
		[dD]([+-]?\d+)        ## group 2: exponent with optional sign
		}x);
	return("$1e$2");
}

package Fortran::Namelist::Editor::Value::single;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::single::ISA=qw{Fortran::Namelist::Editor::Value};
sub get {
	my $self=shift;
	my $value=$self->SUPER::get;
	return(undef) unless ($value=~m{
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*(\.\d+)     ##    group 2: decimal point and digits
			|
			\d+)              ##    without decimal point
		)
		(?:[eE]([+-]?\d+))?   ## group3: exponent with optional sign
		}x);
	return($value);
}

package Fortran::Namelist::Editor::Value::logical;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::logical::ISA=qw{Fortran::Namelist::Editor::Value};
sub get {
	my $self=shift;
	my $value=$self->SUPER::get();
	return(undef) unless ($value=~/^\W*([tTfF])/);
	return(lc($1) eq 'f' ? 0 : 1);
}
sub set {
	my ($self,$new_value) = @_;
	my $old_value = $self->get;
	return(1) if (defined $old_value and ($old_value == $new_value));
	my $value = ($new_value ? '.TRUE.' : '.FALSE.');
	$self->SUPER::set($value);
}

1;
