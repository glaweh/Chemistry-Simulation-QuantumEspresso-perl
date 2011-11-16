package Fortran::Namelist::Editor::Assignment;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Index;
use Fortran::Namelist::Editor::Value;
@Fortran::Namelist::Editor::Assignment::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist,$o_b,$o_e,@options)=@_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	if ($#options == 5) {
		my ($o_name_b,$o_name_e,$o_index_b,$o_index_e,$o_value_b,$o_value_e)=@options;
		$self->{name}  = Fortran::Namelist::Editor::Token->new($namelist,$o_name_b,$o_name_e);
		$self->{index} = Fortran::Namelist::Editor::Index->new($namelist,$o_index_b,$o_index_e);
		$self->{value} = [];
		$self->parse_value($o_value_b,$o_value_e);
	} elsif ($#options == 2) {
		$self->{name}=$options[0];
		$self->{index}=$options[1];
		$self->{value}=$options[2];
	} else {
		$self->{name}  = undef;
		$self->{index} = undef;
		$self->{value} = undef;
	}
	return($self);
}
sub delete {
	my $self=shift;
	my $offset_b=$self->{o_b};
	my $offset_e=$self->{o_e};
	my $debug_extend = 0;
	warn "to_del: '" . substr($self->{_namelist}->{data},$offset_b,$offset_e-$offset_b) . "'" if ($debug_extend);
	my $replacement='';
	# extend area to whitespace up to preceeding newline
	my $chopped_newline=0;
	pos($self->{_namelist}->{data_cs})=$offset_b;
	if ($self->{_namelist}->{data_cs} =~ /([\n,])[ \t]*\G/gs) {
		$chopped_newline = $1 ne ',';
		$offset_b=$-[1];
		warn "ext1: '" . substr($self->{_namelist}->{data},$offset_b,$offset_e-$offset_b) . "'" if ($debug_extend);
	}
	pos($self->{_namelist}->{data_cs})=$offset_e;
	if ($self->{_namelist}->{data_cs} =~ /\G([ \t]+)/gs) {
		$offset_e=$+[1];
		warn "ext2: '" . substr($self->{_namelist}->{data},$offset_b,$offset_e-$offset_b) . "'" if ($debug_extend);
	}
	pos($self->{_namelist}->{data_cs})=$offset_e;
	if ($self->{_namelist}->{data_cs} !~ /\G\n/gs) {
		$replacement="\n$self->{_namelist}->{indent}" if ($chopped_newline);
	}
	# remove the string from data/data_cs
	my $length = $offset_e-$offset_b;
	substr($self->{_namelist}->{data},$offset_b,$length)=$replacement;
	substr($self->{_namelist}->{data_cs},$offset_b,$length)=$replacement;
	$self->{_namelist}->adjust_offsets($offset_b+1,length($replacement)-$length);
}
sub parse_value {
	my ($self,$offset_b,$offset_e)=@_;
	my $data_v      = substr($self->{_namelist}->{data_cs},$offset_b,$offset_e-$offset_b);
	# insert a comma into each group of spaces unless there is already one
	# commas are optional in namelists, this will make it easier to parse
	$data_v =~ s{
		([^\s,])       # last char of a group of non-comma, non-space chars
		\s             # a space, to be substituted by a comma
		(\s*[^\s,])    # first char of the next group of non-comma, non-space chars
		}{$1,$2}gsx;
	die "unimplemented: complex vars" if ($data_v =~ m{\(});
	while ($data_v =~ m{(?:
				([^\s,]+)\s*,?   # value, followed by optional space and comma
			|
				(\s*),           # empty value between two commas
			)}gx) {
		my $val;
		if (defined($1)) {
			$val=Fortran::Namelist::Editor::Value::Auto->new($self->{_namelist},$-[1]+$offset_b,$+[1]+$offset_b);
		}
		push @{$self->{value}},$val;
	}
	return(1);
}

package Fortran::Namelist::Editor::Variable;
use strict;
use warnings;
use Scalar::Util qw(blessed);
@Fortran::Namelist::Editor::Variable::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist)=@_;
	$self->SUPER::init($namelist);
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
	my ($self,$value,@index) = @_;
	if ($#index>=0) {
		die "variable '" . $self->{name}->get . "' was classified as scalar, not array"
	}
	$self->{value}->set($value);
	return(1);
}
sub delete {
	my ($self,@index) = @_;
	if ($#index>=0) {
		die "variable '" . $self->{name}->get . "' was classified as scalar, not array"
	}
	foreach my $instance (@{$self->{instances}}) {
		$instance->delete;
	}
	return(1);
}

package Fortran::Namelist::Editor::Array;
use strict;
use warnings;
use Scalar::Util qw(blessed);
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
		my @index = $instance->{index}->get;
		my $where = $self->{value};
		my $lasti = pop @index;
		foreach (@index) {
			$where->[$_]=[] unless (defined $where->[$_]);
			$where=$where->[$_];
		}
		$where->[$lasti] = $instance->{value}->[0];
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
	my @stack        = (\@result);
	my @source_stack = ($self->{value});
	my @subd_stack	 = [ @padding ];
	while ($#stack >= 0) {
		my $target = pop @stack;
		my $source = pop @source_stack;
		my @subd   = @{ pop @subd_stack };
		my $thisd  = shift @subd;
		if ($#subd < 0) {
			for (my $i=0; $i<$thisd; $i++) {
				if ((defined $source) and (defined $source->[$i])) {
					$target->[$i]=$source->[$i]->get;
				} else {
					$target->[$i]=undef;
				}
			}
		} else {
			for (my $i=0; $i<$thisd; $i++) {
				my @a;
				$target->[$i]=\@a;
				push @stack,\@a;
				push @source_stack,$source->[$i];
				push @subd_stack,[ @subd ];
			}
		}
	}
	return(\@result);
}
sub get {
	my ($self,@index)=@_;
	if ($#index >= 0) {
		my $where = $self->{value};
		foreach (@index) {
			return(undef) unless ((defined $where) and (ref $where eq 'ARRAY'));
			$where=$where->[$_];
		}
		return(undef) unless (blessed($where) and $where->can('get'));
		return($where->get);
	} else {
		return($self->get_whole_cube);
	}
}
sub set {
	my ($self,$value,@index) = @_;
	if ($#index<0) {
		die "variable '" . $self->{name}->get . "' was classified as array, not scalar"
	}
	my $where = $self->{value};
	foreach (@index) {
		return(2) unless ((defined $where) and (ref $where eq 'ARRAY'));
		$where=$where->[$_];
	}
	return(2) unless (blessed($where) and $where->can('get'));
	return($where->set($value));
}
sub delete {
	# return value: 1 if there is no element left
	my ($self,@index)=@_;
	return($self->SUPER::delete) if ($#index<0);
	return(0) unless (defined $self->get(@index));
	for (my $i=0;$i<=$#{$self->{instances}};$i++) {
		my $instance=$self->{instances}->[$i];
		next unless ($instance->{index}->is_equal(@index));
		$instance->delete;
		$self->{instances}->[$i]=undef;
	}
	@{$self->{instances}}  = grep { defined $_ } @{$self->{instances}};
	return(1) if ($#{$self->{instances}} < 0);
	my $where = $self->{value};
	my $lasti = pop @index;
	foreach (@index) {
		$where=$where->[$_];
	}
	$where->[$lasti]=undef;
	return(0);
}
1;
