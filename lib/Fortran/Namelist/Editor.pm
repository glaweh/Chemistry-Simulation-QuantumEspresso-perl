package Fortran::Namelist::Editor;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Scalar::Util qw(reftype blessed);
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Value;
use Fortran::Namelist::Editor::Index;
use Fortran::Namelist::Editor::Assignment;

sub new {
	my $class=shift;
	my $self={};
	bless($self,$class);
	return(undef) unless $self->init(@_);
	return($self);
}

sub init {
	my $self=shift;
	my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'HASH'));
	$self->{filename}    = $opts{filename};
	$self->{data}        = $opts{data};

	# internal data structures
	$self->{_comments}   = [];
	$self->{_groups}     = [];
	$self->{groups}      = {};
	$self->{_groupless}  = [];
	$self->{indent}      = '';

	if (defined $self->{filename} and (! defined $self->{data})) {
		# slurp in file
		if (open(my $fh,$self->{filename})) {
			local $/=undef;
			$self->{data}=<$fh>;
		} else {
			carp "Error opening file '$self->{filename}'";
			return(undef);
		}
	}
	if ($self->{data}) {
		$self->{data_cs}=$self->find_comments_and_strings();
		$self->find_groups();
		$self->find_groupless();
		$self->find_indent();
	}
	return(1);
}

sub find_comments_and_strings {
	my $self = shift;
	my @strings;
	# find all fortran !-style comments and quoted strings
	while ($self->{data} =~ m{
			                   ## f90 comments start with !, end with EOL
			(![^\n]*)\n        ## put into group1
		|                      ## OR ! which are part of quoted strings
			(                  ##group2
				'(?:''|[^'])*' ## single quoted strings, '' is an escaped '
			|
				"(?:""|[^"])*" ## double quoted strings, "" is an escaped "
			)                  ##group2-end
		}xsg) {
		if (defined $2) {
			my %string=(
				o_b => $-[2],
				o_e => $+[2],
			);
			push @strings,\%string;
		} else {
			push @{$self->{_comments}},Fortran::Namelist::Editor::Comment->new($self,$-[1],$+[1]);
		}
	}
	# working copy
	my $d = $self->{data};
	# replace comments by same-length sequence of space
	foreach my $c (@{$self->{_comments}}) {
		substr($d,$c->{o_b},$c->length) = ' ' x $c->length;
	}
	# replace strings by same-length sequence of underscores
	foreach my $s (@strings) {
		my $len=$s->{o_e}-$s->{o_b};
		substr($d,$s->{o_b},$len) = '_' x $len;
	}
	return($d);
}

sub find_groups {
	my $self=shift;
	while ($self->{data_cs} =~ m{(?:^|\n)[ \t]*&(\S+)([^/]*)(/)}gs) {
		push @{$self->{_groups}},{
			name      => Fortran::Namelist::Editor::Token->new($self,$-[1],$+[1]),
			o_b       => $-[0],  # group begins with &
			o_e       => $+[3],    # end of NL group is /
			_vars     => [],
			vars      => {},
		};
		$self->find_vars($self->{_groups}->[-1],$-[2],$+[2]);
	}
	foreach my $g (@{$self->{_groups}}) {
		my $name=$g->{name}->get;
		confess "group '$name' exists more than once" if (exists $self->{groups}->{$name});
		$self->{groups}->{$name}=$g;
		$g->{vars}   = _varhash($g->{_vars});
	}
	return(1);
}

sub find_indent {
	my $self=shift;
	my %indent;
	foreach my $g (@{$self->{_groups}}) {
		# detect indentation within groups
		my $gs = substr($self->{data_cs},$g->{name}->{o_e},$g->{o_e}-$g->{name}->{o_e});
		while ($gs =~ m{(?:^|\n)([ \t]*)\S}gs) {
			$indent{$1}++;
		}
	}
	if (%indent) {
		my @indentations=keys %indent;
		my @votes=values %indent;
		my @idx=sort { $votes[$b] <=> $votes[$a] } 0 .. $#votes;
		$self->{indent}=$indentations[$idx[0]];
	}
}

sub _varhash {
	my $vars_a=shift;
	my %vars;
	foreach my $v (@{$vars_a}) {
		my $name = $v->{name}->get;
		$vars{$name}=Fortran::Namelist::Editor::Variable->new() unless exists ($vars{$name});
		$vars{$name}->add_instance($v);
	}
	return(\%vars);
}

sub find_groupless {
	my $self=shift;
	my $o_last_end=0;
	foreach my $g (@{$self->{_groups}}) {
		$o_last_end=$g->{o_e} if ($g->{o_e} > $o_last_end);
	}
	$self->parse_groupless($o_last_end,length($self->{data}));
	return(1);
}

sub parse_groupless {
	my ($self,$offset_b,$offset_e)=@_;
	my $gl_cs = substr($self->{data_cs},$offset_b,$offset_e-$offset_b);
	if ($gl_cs =~ m{^\s*$}) {
		return(undef);
	}
	my $gl   = substr($self->{data},$offset_b,$offset_e-$offset_b);
	push @{$self->{_groupless}},{
		o_b   => $offset_b,
		o_e   => $offset_e,
		value => $gl,
	};
	return(1);
}

sub find_vars {
	my ($self,$group_ref,$offset_b,$offset_e)=@_;
	my $data_n      = substr($self->{data_cs},$offset_b,$offset_e-$offset_b);
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
		push @offsets,[$-[0]+$offset_b,undef,
			$-[1]+$offset_b,$+[1]+$offset_b,
			$-[2]+$offset_b,$+[2]+$offset_b,
			$+[0]+$offset_b,undef];
	}
	$offsets[-1]->[1]=$offsets[-1]->[7]=$offset_e if ($#offsets>=0);
	for (my $i=0; $i<=$#offsets; $i++) {
		my @offset=@{$offsets[$i]};
		my $val_e = pop @offset;
		my $val_b = pop @offset;
		my $value = $self->find_value($val_b,$val_e);
		push @{$group_ref->{_vars}},Fortran::Namelist::Editor::Assignment->new($self,@offset,$value);
	}
	return(1);
}

sub find_value {
	my ($self,$offset_b,$offset_e)=@_;
	my $data_v      = substr($self->{data_cs},$offset_b,$offset_e-$offset_b);
	# insert a comma into each group of spaces unless there is already one
	# commas are optional in namelists, this will make it easier to parse
	$data_v =~ s{
		([^\s,])       # last char of a group of non-comma, non-space chars
		\s             # a space, to be substituted by a comma
		(\s*[^\s,])    # first char of the next group of non-comma, non-space chars
		}{$1,$2}gsx;
	my @value;
	if ($data_v =~ m{\(}) {
		# complex
		confess "unimplemented: complex vars";
	} else {
		# re-implement split :(
		# assumption: whitespace at beginning and end already stripped
		my $old_e=$offset_b;
		while ($data_v=~m{\s*,\s*}gsx) {
			push @value,Fortran::Namelist::Editor::Value::subclass($self,$old_e,$-[0]+$offset_b);
			$old_e=$+[0]+$offset_b;
		}
		if (substr($data_v,$old_e-$offset_b,$offset_e-$old_e) =~ /\s*$/) {
			$offset_e -= $+[0] - $-[0];
		}
		push @value,Fortran::Namelist::Editor::Value::subclass($self,$old_e,$offset_e);
	}
	return(\@value);
}

sub as_hash {
	my $self=shift;
	my %h;
	while (my ($gname,$g) = each %{$self->{groups}}) {
		my $r=reftype($g);
		next unless (defined $r and ($r eq 'HASH'));
		$h{$gname}={};
		while (my ($vname,$v) = each %{$g->{vars}}) {
			my $r=reftype($v);
			next unless (defined $r and ($r eq 'HASH'));
			$h{$gname}->{$vname}=$v->get;
		}
	}
	return(\%h);
}

sub get {
	my ($self,$group,$variable,$index)=@_;
	return(undef) unless ((exists $self->{groups}->{$group}) and (exists $self->{groups}->{$group}->{vars}->{$variable}));
	return($self->{groups}->{$group}->{vars}->{$variable}->get($index));
}

sub save {
	my ($self,$filename)=@_;
	my $fh;
	confess "cannot open file '$filename' for writing" unless (open($fh,'>',$filename));
	print $fh $self->{data};
	close($fh);
}

sub adjust_offsets {
	my ($self,$start,$delta,$adjust_id) = @_;
	my @stack=($self);
	$adjust_id = int(rand(4242424)) unless (defined $adjust_id);
	while ($#stack >= 0) {
		my $h=pop @stack;
		next unless (defined $h);
		next unless ((defined reftype($h)) and (reftype($h) eq 'HASH'));
		next if ((defined $h->{_adjusted}) and ($h->{_adjusted} == $adjust_id));
		$h->{_adjusted}=$adjust_id;
		foreach my $key (keys %{$h}) {
			my $r=reftype($h->{$key});
			if ($key =~ /^o_.*[be]$/) {
				if (defined $r) {
					if ($r eq 'ARRAY') {
						foreach (@{$h->{$key}}) {
							next unless defined;
							next unless ($_ >= $start);
							$_+=$delta
						}
					}
				} elsif ((defined $h->{$key}) and ($h->{$key} >= $start)) {
					$h->{$key}+=$delta;
				}
			} elsif (defined $r) {
				if (blessed($h->{$key}) and $h->{$key}->can('_adjust_offsets')) {
					$h->{$key}->_adjust_offsets($start,$delta,$adjust_id);
				} elsif ($r eq 'ARRAY') {
					push @stack,@{$h->{$key}};
				} elsif ($r eq 'HASH') {
					push @stack,$h->{$key};
				}
			}
		}
	}
	return($adjust_id);
}

sub _set_value {
	# modify an existing input variable
	#   return codes
	#     1: setting successfull
	#     0: variable does not yet exist
	#     2: array element does not yet exist
	#     3: setting with index, but variable was classified as scalar
	#     4: setting without index, but variable was classified as array
	my ($self,$group_ref,$setting) = @_;
	# setting: var [,index1,...], value
	my @index    = @{$setting};
	my $var      = shift @index;
	# get the description
	my $var_desc = $group_ref->{vars}->{$var};
	unless (defined $var_desc) {
		# variable does not yet exist
		return(0);
	}
	# take the new value
	my $value = pop @index;
	# actually set the variable
	return($var_desc->set($value,@index));
}

sub _add_new_setting {
	my ($self,$group_ref,$setting) = @_;
	# setting: var [,index1,...], value
	my @index     = @{$setting};
	my $var       = shift @index;
	# take the new value
	my $value     = pop @index;
	# insert at end of group's data section
	my $offset_b  = $group_ref->{o_e}-1;
	# variables for dealing with arrays
	my $index_str = '';
	# deal with the index
	if ($#index>=0) {
		# stringify index
		$index_str = Fortran::Namelist::Editor::Index::index2fortranstring(@index);
		# in case of a pre-existing array, find insertion point
		if (exists $group_ref->{vars}->{$var}) {
			# simple solution: put after the last occurrance
			my $last_e=$group_ref->{vars}->{$var}->{instances}->[-1]->{value}->[-1]->{o_e};
			# find newline
			pos($self->{data_cs})=$last_e;
			while ($self->{data_cs} =~ m{\n}gs) {
				$offset_b=$+[0] if ($+[0] < $offset_b);
				last;
			}
		}
	}
	# compute insertion into data_cs
	my $value_cs  = ($value =~ /^["']/ ? '_' x length($value) : $value);
	# insert the line to be inserted into data and data_cs
	my $insert    = "$self->{indent}$var$index_str = $value\n";
	my $insert_cs = "$self->{indent}$var$index_str = $value_cs\n";
	substr($self->{data}   ,$offset_b,0)=$insert;
	substr($self->{data_cs},$offset_b,0)=$insert_cs;
	# update old offsets
	$self->adjust_offsets($offset_b,length($insert));

	# create data structures
	my $name_end  = length($self->{indent})+length($var)+$offset_b;
	my $index_end = $name_end+length($index_str);
	my $v = Fortran::Namelist::Editor::Assignment->new($self,
		$offset_b,$offset_b+length($insert),
		length($self->{indent})+$offset_b,$name_end,
		$name_end,$index_end,
		[ Fortran::Namelist::Editor::Value::subclass($self,$index_end+3,$index_end+3+length($value)) ]);
	my $index_perl = (defined $v->{index} ? $v->{index}->get : '');
	push @{$group_ref->{_vars}},$v;
	my $desc;
	# setup description
	if ($#index < 0) {
		# no array
		$desc = Fortran::Namelist::Editor::Variable->new($self->{container});
		$group_ref->{vars}->{$var}=$desc;
	} else {
		$desc=$group_ref->{vars}->{$var};
		unless (defined $desc) {
			# new array
			$desc = Fortran::Namelist::Editor::Array->new($self->{container});
			$group_ref->{vars}->{$var}=$desc;
		}
	}
	$desc->add_instance($v);
}

sub add_group {
	my ($self,$group_name,$after)=@_;
	return(2) if (exists $self->{groups}->{$group_name});
	my $after_index = $#{$self->{_groups}};
	if (defined $after) {
		if ($after =~ /^\d+$/) {
			$after_index=$after if ($after < $after_index);
		} elsif (exists $self->{groups}->{$after}) {
			$after_index = grep { $self->{_groups}->[$_]->{name}->get eq $after } 0 .. $#{$self->{_groups}};
			$after_index--;
		}
	}
	my $offset_b    = $self->{_groups}->[$after_index]->{o_e};
	my $insert      = "\n&$group_name\n/";
	substr($self->{data},$offset_b,0)=$insert;
	substr($self->{data_cs},$offset_b,0)=$insert;
	$self->adjust_offsets($offset_b+1,length($insert));
	my %group = (
			name      => Fortran::Namelist::Editor::Token->new($self,1+$offset_b,length($group_name)+1+$offset_b),
			o_b       => $offset_b,                       # group begins with &
			o_e       => length($group_name)+4+$offset_b, # end of NL group is /
			_vars     => [],
			vars      => {},
	);
	splice(@{$self->{_groups}},$after_index+1,0,\%group);
	$self->{groups}->{$group_name}=\%group;
}

sub remove_group {
	my ($self,$group_name)=@_;
	return(2) unless (exists $self->{groups}->{$group_name});
	my $group_ref = $self->{groups}->{$group_name};
	@{$self->{_groups}} = grep { $_ != $group_ref } @{$self->{_groups}};
	delete($self->{groups}->{$group_name});
	@{$self->{_comments}} = grep { ! (($_->{o_b} > $group_ref->{o_b}) and ($_->{o_e} < $group_ref->{o_e})) }
		@{$self->{_comments}};
	substr($self->{data},$group_ref->{o_b},$group_ref->{o_e}-$group_ref->{o_b})='';
	substr($self->{data_cs},$group_ref->{o_b},$group_ref->{o_e}-$group_ref->{o_b})='';
	$self->adjust_offsets($group_ref->{o_b},$group_ref->{o_b}-$group_ref->{o_e});
}

sub set {
	my ($self,$group,@settings)=@_;
	unless (exists $self->{groups}->{$group}) {
		$self->add_group($group);
	}
	my $g=$self->{groups}->{$group};
	foreach my $setting_o (@settings) {
		confess "Needs array ref" unless (ref $setting_o eq 'ARRAY');
		my $set_result=$self->_set_value($g,$setting_o);
		next if ($set_result == 1); # value successfully modified
		if (($set_result == 0) or ($set_result == 2)) {
			$self->_add_new_setting($g,$setting_o);
		} else {
			confess "Do not know how to continue";
		}
	}
}

sub _unset {
	my ($self,$group_ref,$setting)=@_;
	# setting: var [,index1,...]
	my @index     = @{$setting};
	my $var       = shift @index;
	return(2) unless (exists $group_ref->{vars}->{$var});
	my $desc = $group_ref->{vars}->{$var};
	my $index_perl;
	if ($#index >= 0) {
		$index_perl=Fortran::Namelist::Editor::Index::index2perlrefstring(@index);
		my $val_test;
		eval "\$val_test = \$desc->{values}$index_perl;";
		return(2) unless (defined $val_test);
	}
	my %instance_removed;
	foreach my $instance (@{$desc->{instances}}) {
		if ($index_perl) {
			next unless ($instance->{index}->get eq $index_perl);
		}
		$instance_removed{$instance}=1;
		$instance->delete;
	}
	# kill the reference from the group_ref
	@{$group_ref->{_vars}} = grep { ! $instance_removed{$_} } @{$group_ref->{_vars}};
	@{$desc->{instances}}  = grep { ! $instance_removed{$_} } @{$desc->{instances}};
	if ($index_perl) {
		# clean up array descriptor
		if ($#{$desc->{instances}}<0) {
			# empty, delete altogether
			delete ($group_ref->{vars}->{$var});
		} else {
			# stamp out elements
			eval "\$desc->{values}$index_perl = undef;";
		}
	}
	delete ($group_ref->{vars}->{$var}) if ($#{$desc->{instances}} < 0);
}

sub unset {
	my ($self,$group,@settings)=@_;
	unless (exists $self->{groups}->{$group}) {
		return(2);
	}
	my $g=$self->{groups}->{$group};
	foreach my $setting (@settings) {
		confess "Needs array ref" unless (ref $setting eq 'ARRAY');
		my $unset_result=$self->_unset($g,$setting);
	}
}

1;
