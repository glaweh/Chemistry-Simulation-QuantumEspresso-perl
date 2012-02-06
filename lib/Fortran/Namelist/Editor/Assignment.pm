package Fortran::Namelist::Editor::Assignment;
use strict;
use warnings;
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Index;
use Fortran::Namelist::Editor::Value;
my $DEBUG = 0;
@Fortran::Namelist::Editor::Assignment::ISA = qw{Fortran::Namelist::Editor::ContainerSpan};
sub init {
	my ($self,$namelist,$o_b,$o_e,@options)=@_;
	$self->SUPER::init($namelist,$o_b,$o_e);
	if ($#options == 5) {
		my ($o_name_b,$o_name_e,$o_index_b,$o_index_e,$o_value_b,$o_value_e)=@options;
		$self->{name}  = Fortran::Namelist::Editor::Token->new($namelist,$o_name_b,$o_name_e);
		$self->{index} = undef;
		$self->{index} = Fortran::Namelist::Editor::Index->new($namelist,$o_index_b,$o_index_e)
			if (($o_index_e-$o_index_b) > 0);
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
	my $offset_b=$self->{_o}->[0];
	my $offset_e=$self->{_o}->[1];
	my $replacement='';
	# extend area to whitespace up to preceeding newline
	$offset_b=$self->{_namelist}->refine_offset_back($offset_b,qr{([\n,])[ \t]*}s);
	$offset_e=$self->{_namelist}->refine_offset_forward($offset_e,qr{([ \t]*,)}s);
	my $chopped_comma_after= ($offset_e != $self->{_o}->[1]);
	$offset_e=$self->{_namelist}->refine_offset_forward($offset_e,qr{([ \t]*)}s);
	my $data=$self->{_namelist}->get_data($offset_b,$offset_e+1);
	if ($data !~ /\n$/) {
		if ($data =~ /^\n/) {
			$replacement="\n$self->{_namelist}->{indent}";
		} elsif (($data =~ /^,/) and ($chopped_comma_after)) {
			$replacement=", ";
		}
	}
	# remove the string from data/data_cs
	$self->{_namelist}->set_data($offset_b,$offset_e,$replacement);
	$self->{_namelist}->_remove_GOT_entry($self->{_o});
	return(1);
}
sub parse_value {
	my ($self,$offset_b,$offset_e,$type)=@_;
	my (undef,$data_v) = $self->{_namelist}->get_data($offset_b,$offset_e);
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
			$val=Fortran::Namelist::Editor::Value::Auto->new($self->{_namelist},$-[1]+$offset_b,$+[1]+$offset_b,$type);
		}
		push @{$self->{value}},$val;
	}
	return(1);
}
sub insert {
	my ($class,$namelist,$o_b,$separator,$name,$value,@index) = @_;
	my $type = 'Fortran::Namelist::Editor::Value::Auto';
	if (defined $index[-1] and $index[-1] !~ /^\d+$/) {
		my $t = pop @index;
		if ($t =~ /:/) {
			$type=$t;
		} else {
			$type="Fortran::Namelist::Editor::Value::$t";
		}
	}
	my ($name_o,$index_o,$val_o,$o_e);
	$name_o       = Fortran::Namelist::Editor::Token->insert($namelist,$o_b,$separator,$name);
	$o_b          = $name_o->{_o}->[0];
	$o_e          = $name_o->{_o}->[1];
	$index_o      = Fortran::Namelist::Editor::Index->insert($namelist,$o_e,'',@index);
	$o_e          = $index_o->{_o}->[1] if (defined $index_o);
	$val_o        = $type->insert($namelist,$o_e,' = ',$value);
	$o_e          = $val_o->{_o}->[1];
	my $a         = $class->new($namelist,$o_b,$o_e,$name_o,$index_o,[ $val_o ]);
	return($a);
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
		print STDERR "interpreting var '$name' as array (reason: index)\n" if ($DEBUG > 0);
		$switch_to_array = 1;
	}
	if ($#{$instance->{value}} > 0) {
		print STDERR "interpreting var '$name' as array (reason: multiple values)\n" if ($DEBUG > 0);
		$switch_to_array = 1;
	}
	if ($switch_to_array) {
		bless($self,'Fortran::Namelist::Editor::Array');
		$self->_switch_to_array;
		return($self->add_instance($instance));
	}
	push @{$self->{instances}},$instance;
	$self->_update_offsets_from_instances();
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
	return($self->{value}->set($value));
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
sub insert {
	my ($class,$namelist,$o_b,$separator,$name,$value,@index) = @_;
	my $a = Fortran::Namelist::Editor::Assignment->insert($namelist,$o_b,
		$separator,$name,$value,@index);
	my $self=$class->new($namelist);
	$self->add_instance($a);
	return($self);
}
sub _update_offsets_from_instances {
	my $self = shift;
	my ($o_b,$o_e);
	foreach my $instance (@{$self->{instances}}) {
		$o_b = $instance->{_o}->[0] if ((! defined $o_b) or ($instance->{_o}->[0] < $o_b));
		$o_e = $instance->{_o}->[1] if ((! defined $o_e) or ($instance->{_o}->[1] > $o_e));
	}
	$self->{_o}->[0]=$o_b;
	$self->{_o}->[1]=$o_e;
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
	$self->_update_offsets_from_instances();
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
	if (blessed($where) and $where->can('get')) {
		my @res = $where->set($value);
		$self->_update_offsets_from_instances();
		return(@res);
	} else {
		# insert new statement after the last
		my ($o_insert,$a);
		$o_insert=$self->{_namelist}->insert_new_line_after($self->{instances}->[-1]->{_o}->[1]);
		$a       = Fortran::Namelist::Editor::Assignment->insert($self->{_namelist},$o_insert,'',
			$self->{name}->get,$value,@index,blessed($self->{instances}->[0]->{value}->[0]));
		$self->add_instance($a) if (defined $a);
		$self->_update_offsets_from_instances();
		return(1);
	}
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
	my $where = $self->{value};
	my $lasti = pop @index;
	foreach (@index) {
		$where=$where->[$_];
	}
	$where->[$lasti]=undef;
	my $is_empty=0;
	$is_empty=1 if ($#{$self->{instances}} < 0);
	if ($is_empty == 0) {
		$self->_update_offsets_from_instances();
	}
	return($is_empty);
}
1;
