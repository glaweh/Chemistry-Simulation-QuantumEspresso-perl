package Fortran::Namelist::Editor;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Scalar::Util qw(reftype blessed);
use Fortran::Namelist::Editor::Span;
use Fortran::Namelist::Editor::Value;

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
			name      => $1,
			o_name_b  => $-[1],
			o_name_e  => $+[1],
			o_vars_b  => $-[2],
			o_vars_e  => $+[2],
			o_b       => $-[0],  # group begins with &
			o_e       => $+[3],    # end of NL group is /
			_vars     => $self->find_vars($-[2],$+[2]),
			vars      => {},
		};
	}
	foreach my $g (@{$self->{_groups}}) {
		my $name=$g->{name};
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
		my $gs = substr($self->{data_cs},$g->{o_vars_b},$g->{o_vars_e}-$g->{o_vars_b});
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
		my $name = $v->{name};
		push @{$vars{$name}->{instances}},$v;
	}
	while (my ($name,$desc) = each %vars) {
		# check for/guess array-ness
		$desc->{is_array} = 0;
		foreach my $inst (@{$vars{$name}->{instances}}) {
			if (defined $inst->{index}) {
				print STDERR "interpreting var '$name' as array (reason: index)\n";
				$desc->{is_array} = 1;
			}
			if ($#{$inst->{value}} > 0) {
				print STDERR "interpreting var '$name' as array (reason: multiple values)\n";
				$desc->{is_array} = 1;
			}
		}
		if ($desc->{is_array}) {
			$desc->{values}=[];
			$desc->{values_source}=[];
			foreach my $inst (@{$vars{$name}->{instances}}) {
				if (defined $inst->{index}) {
					if ($#{$inst->{index}} > 0) {
						confess "only 1d-indices are implemented";
					}
					if ($#{$inst->{value}} > 0) {
						confess "only 1d-values are implemented";
					}
					$desc->{values}->[$inst->{index}->[0]->{element}]=$inst->{value}->[0]->{value};
					$desc->{values_source}->[$inst->{index}->[0]->{element}]=$inst->{value}->[0];
				} else {
					for (my $i=0;$i<=$#{$inst->{value}};$i++) {
						$desc->{values}->[$i+1]=$inst->{value}->[$i]->{value};
						$desc->{values_source}->[$i+1]=$inst->{value}->[$i];
					}
				}
			}
		} else {
			foreach my $inst (@{$vars{$name}->{instances}}) {
				$desc->{value}        = $inst->{value}->[0]->{value};
				$desc->{value_source} = $inst->{value}->[0];
			}
		}
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
	my ($self,$offset_b,$offset_e)=@_;
	my $data_n      = substr($self->{data_cs},$offset_b,$offset_e-$offset_b);
	my @vars;
	my (@vals_b,@vals_e);
	# scan data_n for variables: name, optionally index, followed by '='
	while ($data_n=~m{,?\s+         ## variable assignments are separated by whitespace, optionally with a preceeding comma
			([a-zA-Z][^\(\s]+)      ## a fortran identifier starts with a letter
			\s*((?:\([^\)]*\)\s*?)*)## there may be more than one index statement attached to each variable
			\s*=\s*                 ## = separates variable and value, maybe enclosed by whitespace
		}gsx) {
		my $index      = $self->parse_index($-[2]+$offset_b,$+[2]+$offset_b);
		my $index_perl;
		if (defined $index) {
			my @elems = map { $_->{element} } @{$index};
			$index_perl=join('',map { "->[$_]" } @elems);
		}
		my %v = (
			name      => $1,
			o_name_b  => ($-[1]+$offset_b),
			o_name_e  => ($+[1]+$offset_b),
			index     => $index,
			index_perl=> $index_perl,
			o_index_b => (($2 ? $-[2] : $+[1]) + $offset_b),
			o_index_e => (($2 ? $+[2] : $+[1]) + $offset_b),
			value     => undef,
			o_decl_b  => ($-[0]+$offset_b),
		);
		push @vars,\%v;
		push @vals_e,$-[0]+$offset_b if ($#vals_b >=0 );
		push @vals_b,$+[0]+$offset_b;
	}
	push @vals_e,$offset_e if ($#vals_b >= 0);
	for (my $i=0; $i<=$#vars; $i++) {
		# fill in the value
		$vars[$i]->{value}=$self->find_value($vals_b[$i],$vals_e[$i]);
	}
	return(\@vars);
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
			push @value,$self->parse_value($old_e,$-[0]+$offset_b);
			$old_e=$+[0]+$offset_b;
		}
		if (substr($data_v,$old_e-$offset_b,$offset_e-$old_e) =~ /\s*$/) {
			$offset_e -= $+[0] - $-[0];
		}
		push @value,$self->parse_value($old_e,$offset_e);
	}
	return(\@value);
}

sub parse_value {
	my ($self,$offset_b,$offset_e)=@_;
	my $data;
	if (ref $self) {
		$data=substr($self->{data},$offset_b,$offset_e-$offset_b);
	} else {
		$data=$self;
		$offset_b=0 unless (defined $offset_b);
		$offset_e=$offset_b + length($data) unless (defined $offset_e);
	}
	my %value = (
		type  => undef,
		value => $data,
		o_b   => $offset_b,
		o_e   => $offset_e,
	);
	if ($data =~ /^["']/) {
		$value{type}='string';
	} elsif ($data =~ m{
			(                     ## group 1: mantissa
				[+-]?\d*          ## before decimal point
				(\.\d+)           ##   group 2: decimal point and digits
				|
				\d+               ##   no decimal point
			)
			(?:
				(?:[eE]|([dD]))   ##   group 3: [dD] for double precision
				([+-]?\d+)        ##   group 4: exponent
			)?}x) {
		if (defined $3) {
			$value{value}="$1e$4"; # perl does not understand fortrans 'd' notation
			$value{type} ='double';
		} elsif ((defined $2) or (defined $4)) {
			$value{type} ='single';
		} else {
			$value{type} ='integer';
		}
	} elsif ($data =~ m/^\W*[tT]/) {
		$value{type}  = 'logical';
		$value{value} = 1;
	} elsif ($data =~ m/^\W*[fF]/) {
		$value{type}  = 'logical';
		$value{value} = 0;
	}
	return(\%value);
}

sub parse_index {
	my ($self,$offset_b,$offset_e)=@_;
	my $data      = substr($self->{data},$offset_b,$offset_e-$offset_b);
	return(undef) if ($data=~m{^\s*$}); # no index
	# remove enclosing brackets
	if ((my $nbrackets = ($data =~ s{\(([^\)]+)\)}{ $1 }g)) != 1) {
		confess "No enclosing brackets in '$data'" if ($nbrackets == 0);
		confess "Subindexing is not supported '$data'";
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
		confess "Only explicit indexing is supported: '$data'";
	}
	if ($data !~ m{^[\s\d,]+$}) {
		confess "Don't know how to parse '$data'";
	}
	my @index;
	while ($data=~m{(\d+)}gxs) {
		my %index_element=(
			element     => $1,
			o_element_b => $-[1]+$offset_b,
			o_element_e => $+[1]+$offset_b,
		);
		push @index,\%index_element;
	}
	return(\@index);
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
			if ($v->{is_array}) {
				$h{$gname}->{$vname}=$v->{values};
			} else {
				$h{$gname}->{$vname}=$v->{value};
			}
		}
	}
	return(\%h);
}

sub get {
	my ($self,$group,$variable,$index)=@_;
	return(undef) unless ((exists $self->{groups}->{$group}) and (exists $self->{groups}->{$group}->{vars}->{$variable}));
	my $v=$self->{groups}->{$group}->{vars}->{$variable};
	if ($v->{is_array}) {
		if (defined $index) {
			return($v->{values}->[$index]);
		} else {
			return($v->{values});
		}
	} else {
		return($v->{value});
	}
}

sub save {
	my ($self,$filename)=@_;
	my $fh;
	confess "cannot open file '$filename' for writing" unless (open($fh,'>',$filename));
	print $fh $self->{data};
	close($fh);
}

sub adjust_offsets {
	my ($self,$start,$delta,@skip) = @_;
	my @stack=($self);
	my $adjust_id = int(rand(4242424));
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
	# and look for the existing value
	my ($val,$val_ref);
	if ($#index >= 0) {
		unless ($var_desc->{is_array}) {
			carp "variable '$var' is classified as scalar, not array";
			return(3);
		}
		my $md_index=join('',map { "->[$_]" } @index);
		eval "\$val_ref = \\\$var_desc->{values}$md_index;";
		eval "\$val = \$var_desc->{values_source}$md_index;";
		return(2) unless (defined $val);
	} else {
		if ($var_desc->{is_array}) {
			carp "variable '$var' is classified as array, not scalar";
			return(4);
		}
		$val=$var_desc->{value_source};
		$val_ref=\$var_desc->{value};
	}
	# actually set the variable
	my $new_length = length($value);
	my $old_length = $val->{o_e}-$val->{o_b};
	substr($self->{data},$val->{o_b},$old_length) = $value;
	if ($value =~ /^['"]/) {
		substr($self->{data_cs},$val->{o_b},$old_length) = '_' x $new_length;
	} else {
		substr($self->{data_cs},$val->{o_b},$old_length) = $value;
	}
	$val->{value}=$value;
	my $delta_o = $new_length-$old_length;
	if ($delta_o != 0) {
		$self->adjust_offsets($val->{o_b}+1,$delta_o);
	}
	${$val_ref}=$val->{value};
	return(1);
}

sub _add_new_setting {
	my ($self,$group_ref,$setting) = @_;
	# setting: var [,index1,...], value
	my @index     = @{$setting};
	my $var       = shift @index;
	# take the new value
	my $value     = pop @index;
	# insert at end of group's data section
	my $offset_b  = $group_ref->{o_vars_e};
	# variables for dealing with arrays
	my $index_str = '';
	my $index_ref = undef;
	my $index_perl = undef;
	# deal with the index
	if ($#index>=0) {
		# stringify index
		$index_str = '(' . join(',',@index) . ')';
		$index_perl=join('',map { "->[$_]" } @index);
		# setup index data structure
		my $position=1;
		foreach my $element (@index) {
			push @{$index_ref},{
				element     => $element,
				o_element_b => $position,
				o_element_e => $position+length($element),
			};
			$position=$index_ref->[-1]->{o_element_e}+1;
		}
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
	my $val       = parse_value($value,$index_end+3);
	my %v=(
		name       => $var,
		o_decl_b   => $offset_b,
		o_name_b   => length($self->{indent})+$offset_b,
		o_name_e   => $name_end,
		index      => $index_ref,
		index_perl => $index_perl,
		o_index_b  => $name_end,
		o_index_e  => $index_end,
		value      => [ $val ],
	);
	push @{$group_ref->{_vars}},\%v;
	# setup description
	if ($#index < 0) {
		# no array
		my %desc = (
			is_array     => 0,
			value        => $val->{value},
			value_source => $val,
			instances    => [ $val ],
		);
		$group_ref->{vars}->{$var}=\%desc;
	} else {
		my $desc=$group_ref->{vars}->{$var};
		unless (defined $desc) {
			# new array
			$group_ref->{vars}->{$var}->{is_array}=1;
			$group_ref->{vars}->{$var}->{instances}=[ $val ];
			$desc=$group_ref->{vars}->{$var};
		}
		eval "\$desc->{values}$index_perl = $val->{value};";
		eval "\$desc->{values_source}$index_perl = \$val;";
	}
}

sub add_group {
	my ($self,$group_name,$after)=@_;
	return(2) if (exists $self->{groups}->{$group_name});
	my $after_index = $#{$self->{_groups}};
	if (defined $after) {
		if ($after =~ /^\d+$/) {
			$after_index=$after if ($after < $after_index);
		} elsif (exists $self->{groups}->{$after}) {
			$after_index = grep { $self->{_groups}->[$_]->{name} eq $after } 0 .. $#{$self->{_groups}};
			$after_index--;
		}
	}
	my $offset_b    = $self->{_groups}->[$after_index]->{o_e};
	my $insert      = "\n&$group_name\n/";
	substr($self->{data},$offset_b,0)=$insert;
	substr($self->{data_cs},$offset_b,0)=$insert;
	$self->adjust_offsets($offset_b+1,length($insert));
	my %group = (
			name      => lc($group_name),
			o_name_b  => 1+$offset_b,
			o_name_e  => length($group_name)+1+$offset_b,
			o_vars_b  => length($group_name)+3+$offset_b,
			o_vars_e  => length($group_name)+3+$offset_b,
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

sub _remove_instance {
	my ($self,$instance) = @_;
	my $offset_b=$instance->{o_decl_b};
	my $offset_e=$instance->{value}->[-1]->{o_e};
	my $length=$offset_e-$offset_b;
	my $replacement='';
	# check if there is data in the same line
	pos($self->{data})=$offset_e;
	if ($self->{data} =~ /\G(,[ \t]*)([^\n]*)\n/gs) {
		$length+=$+[1]-$-[1];
		$replacement="\n$self->{indent}";
	}
	# remove the string from data/data_cs
	substr($self->{data},$offset_b,$length)=$replacement;
	substr($self->{data_cs},$offset_b,$length)=$replacement;
	$self->adjust_offsets($offset_b,length($replacement)-$length);
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
		$index_perl=join('',map { "->[$_]" } @index);
		my $val_test;
		eval "\$val_test = \$desc->{values}$index_perl;";
		return(2) unless (defined $val_test);
	}
	my %instance_removed;
	foreach my $instance (@{$desc->{instances}}) {
		if ($index_perl) {
			next unless ($instance->{index_perl} eq $index_perl);
		}
		$instance_removed{$instance}=1;
		$self->_remove_instance($instance);
	}
	# kill the reference from the group_ref
	@{$group_ref->{_vars}} = grep { ! $instance_removed{$_} } @{$group_ref->{_vars}};
	if ($index_perl) {
		# clean up array descriptor
		@{$desc->{instances}} = grep { ! $instance_removed{$_} } @{$desc->{instances}};
		if ($#{$desc->{instances}}<0) {
			# empty, delete altogether
			delete ($group_ref->{vars}->{$var});
		} else {
			# stamp out elements
			eval "\$desc->{values}$index_perl = undef;";
			eval "\$desc->{values_source}$index_perl = undef;";
		}
	}
	delete ($group_ref->{vars}->{$var});
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
