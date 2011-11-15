package Fortran::Namelist::Editor::Assignment;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Index;
use Fortran::Namelist::Editor::Value;
@Fortran::Namelist::Editor::Assignment::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
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

package Fortran::Namelist::Editor::Variable;
use strict;
use warnings;
use Scalar::Util qw(blessed);
@Fortran::Namelist::Editor::Variable::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$container)=@_;
	$self->SUPER::init($container);
	$self->{name}      = undef;
	$self->{instances} = [ ];
	$self->{value}     = undef;
	return($self);
}
sub add_instance {
	my ($self,$instance) = @_;
	my $switch_to_array=0;
	$self->{name}=$instance->{name} unless (defined $self->{name});
	my $iname = $instance->{name}->get;
	my $name  = $self->{name}->get;
	if ($iname ne $name) {
		die "Trying to assemble assignments with different names";
	}
	if (defined $instance->{index}) {
		print STDERR "interpreting var '$name' as array (reason: index)\n";
		$switch_to_array = 1;
	}
	if ($#{$instance->{value}} > 0) {
		print STDERR "interpreting var '$name' as array (reason: multiple values)\n";
		$switch_to_array = 1;
	}
	if ($switch_to_array) {
		bless($self,'Fortran::Namelist::Editor::Array');
		$self->_switch_to_array;
		return($self->add_instance($instance));
	}
	push @{$self->{instances}},$instance;
	if (blessed $instance->{value}->[0] and $instance->{value}->[0]->can('get')) {
		$self->{value}        = $instance->{value}->[0];
	} else {
		$self->{value}        = undef;
	}
}
sub get {
	my $self=shift;
	return(undef) unless (defined $self->{value});
	return(undef) unless (blessed($self->{value}) and $self->{value}->can('get'));
	return($self->{value}->get);
}
sub set {
	my ($self,$value,$index) = @_;
	if ($#{$index}>=0) {
		die "variable '" . $self->{name}->get . "' was classified as scalar, not array"
	}
	$self->{value}->set($value);
	return(1);
}

package Fortran::Namelist::Editor::Array;
use strict;
use warnings;
@Fortran::Namelist::Editor::Array::ISA=qw{Fortran::Namelist::Editor::Variable};
sub _switch_to_array {
	my $self=shift;
	if (defined $self->{value}) {
		unless (ref $self->{value} eq 'ARRAY') {
			$self->{value} = [ $self->{value} ];
		}
	} else {
		$self->{value} = [];
	}
}
sub add_instance {
	my ($self,$instance) = @_;
	push @{$self->{instances}},$instance;
	if (defined $instance->{index}) {
		if ($#{$instance->{value}} > 0) {
			die "only 1d-values are implemented";
		}
		my $index_perl=$instance->{index}->get;
		eval "\$self->{value}$index_perl = \$instance->{value}->[0]; ";
	} else {
		for (my $i=0;$i<=$#{$instance->{value}};$i++) {
			$self->{value}->[$i]=$instance->{value}->[$i];
		}
	}
}
sub get_dimensions {
	# BFS for dimensionality
	my $self=shift;
	my @dimension;
	foreach my $instance (@{$self->{instances}}) {
		my @dimi = $instance->{index}->get;
		for (my $i=0;$i<=$#dimi;$i++) {
			my $dimi=$dimi[$i]+1;
			$dimension[$i] = $dimi if ((! defined $dimension[$i]) or ($dimension[$i] < $dimi));
		}
	}
	return(\@dimension);
}
sub get_whole_cube {
	my ($self,$padding_in) = @_;
	$padding_in = $self->{_padding} if ((! defined $padding_in) and $self->{_padding});
	$padding_in = $self->get_dimensions unless (defined $padding_in);
	my @padding = @{$padding_in};
	my @result;
	my @stack       = (\@result);
	my @subd_stack	= [ @padding ];
	while ($#stack >= 0) {
		my $target = pop @stack;
		my @subd   = @{ pop @subd_stack };
		my $thisd  = shift @subd;
		if ($#subd < 0) {
			for (my $i=0; $i<$thisd; $i++) {
				$target->[$i]=0;
			}
		} else {
			for (my $i=0; $i<$thisd; $i++) {
				my @a;
				$target->[$i]=\@a;
				push @stack,\@a;
				push @subd_stack,[ @subd ];
			}
		}
	}
	return(\@result);
}
sub get {
	my ($self,@index)=@_;
	if ($#index >= 0) {
		my $index_perl = Fortran::Namelist::Editor::Index::index2perlrefstring(@index);
		my $val;
		eval "\$val = \$self->{value}$index_perl;";
		return($val);
	} else {
		return($self->get_whole_cube);
	}
}
sub set {
	my ($self,$value,$index) = @_;
	if ($#{$index}<0) {
		die "variable '" . $self->{name}->get . "' was classified as array, not scalar"
	}
	my $index_perl = Fortran::Namelist::Editor::Index::index2perlrefstring(@{$index});
	my $val;
	eval "\$val = \$self->{value}$index_perl;";
	return($val->set($value)) if (defined $val);
	return(2);
}
1;
