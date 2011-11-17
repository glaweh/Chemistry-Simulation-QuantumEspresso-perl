package Fortran::Namelist::Editor::Value;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
@Fortran::Namelist::Editor::Value::ISA=qw{Fortran::Namelist::Editor::Span};
sub to_perl {
	my ($self,$value)=@_;
	return($value);
}
sub to_data {
	my ($self,$value)=@_;
	return($value,$value);
}
sub get {
	my $self  = shift;
	my $value = $self->SUPER::get;
	return($self->to_perl($value));
}
sub set {
	my ($self,$value) = @_;
	my @data=$self->to_data($value);
	return(undef) unless (defined $data[0]);
	return($self->SUPER::set(@data));
}

package Fortran::Namelist::Editor::Value::string;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::string::ISA=qw{Fortran::Namelist::Editor::Value};
sub to_perl {
	my ($self,$val)=@_;
	if ($val =~ s/^'(.*)'$/$1/) {
		$val =~ s/''/'/g;
	} elsif ($val =~ s/^"(.*)"$/$1/) {
		$val =~ s/""/"/g;
	} else {
		return undef;
	}
	return($val);
}
sub to_data {
	my ($self,$val)=@_;
	$val =~ s/'/''/g;
	$val = "'$val'";
	my $val_cs= '_' x length($val);
	return($val,$val_cs);
}

package Fortran::Namelist::Editor::Value::integer;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::integer::ISA=qw{Fortran::Namelist::Editor::Value};
sub to_perl {
	my ($self,$val)=@_;
	return(undef) unless ($val =~ /^\d+$/);
	return($val);
}
sub to_data {
	my ($self,$val)=@_;
	return(undef) unless ($val =~ /^\d+$/);
	return($val,$val);
}

package Fortran::Namelist::Editor::Value::double;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::double::ISA=qw{Fortran::Namelist::Editor::Value};
sub to_perl {
	my ($self,$val)=@_;
	return(undef) unless ($val=~s{^
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*\.\d+       ##    with decimal point
			|
			\d+)              ##    without decimal point
		)
		[dD]([+-]?\d+)        ## group 2: exponent with optional sign
		$}{$1e$2}x);
	return($val);
}
sub to_data {
	my ($self,$val)=@_;
	return(undef) unless ($val=~m{^
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*\.\d+       ##    with decimal point
			|
			\d+)              ##    without decimal point
		)
		(?:[eE]([+-]?\d+))?   ## group 2: exponent with optional sign
		$}x);
	$val=$1 . 'd' . (defined $2 ? $2 : '0');
	return($val,$val);
}
package Fortran::Namelist::Editor::Value::single;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::single::ISA=qw{Fortran::Namelist::Editor::Value};
sub to_perl {
	my ($self,$val)=@_;
	return(undef) unless ($val=~m{
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*(\.\d+)     ##    group 2: decimal point and digits
			|
			\d+)              ##    without decimal point
		)
		(?:[eE]([+-]?\d+))?   ## group3: exponent with optional sign
		}x);
	return($val);
}
sub to_data {
	my ($self,$val)=@_;
	return(undef) unless ($val=~m{
		(                     ## group1: mantissa
			[+-]?             ##    optional sign
			(?:\d*(\.\d+)     ##    group 2: decimal point and digits
			|
			\d+)              ##    without decimal point
		)
		(?:[eE]([+-]?\d+))?   ## group3: exponent with optional sign
		}x);
	return($val,$val);
}

package Fortran::Namelist::Editor::Value::logical;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::logical::ISA=qw{Fortran::Namelist::Editor::Value};
sub to_perl {
	my ($self,$val)=@_;
	return(undef) unless ($val=~/^\W*([tTfF])/);
	return(lc($1) eq 'f' ? 0 : 1);
}
sub to_data {
	my ($self,$new_value) = @_;
	my $val = ($new_value ? '.TRUE.' : '.FALSE.');
	return($val,$val);
}

package Fortran::Namelist::Editor::Value::Auto;
use strict;
use warnings;
@Fortran::Namelist::Editor::Value::Auto::ISA=qw{Fortran::Namelist::Editor::Value};
sub new {
	my ($class,$namelist,$o_b,$o_e) = @_;
	my $val = substr($namelist->{data},$o_b,$o_e-$o_b);
	$class=detect_data($val);
	return($class->new($namelist,$o_b,$o_e));
}
sub insert {
	my ($class,$namelist,$o_b,$separator,$value) = @_;
	$class=detect_perl($value);
	return($class->insert($namelist,$o_b,$separator,$value));
}
sub detect_data {
	my $val = shift;
	my ($class,$res);
	foreach (qw{
		Fortran::Namelist::Editor::Value::logical
		Fortran::Namelist::Editor::Value::integer
		Fortran::Namelist::Editor::Value::single
		Fortran::Namelist::Editor::Value::double
		Fortran::Namelist::Editor::Value::string}) {
		$res = $_->to_perl($val);
		if (defined $res) {
			$class=$_;
			last;
		}
	}
	return($class);
}
sub detect_perl {
	my $val = shift;
	my ($class,@res);
	foreach $class (qw{
		Fortran::Namelist::Editor::Value::single
		Fortran::Namelist::Editor::Value::string}) {
		@res = $class->to_data($val);
		last if (defined $res[0]);
	}
	return(undef) unless (defined $res[0]);
	return($class);
}
1;
