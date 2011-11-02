package Fortran::Namelist::Editor;
use strict;
use warnings;
use Carp;
use Data::Dumper;

sub new {
	my $class=shift;
	my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'HASH'));
	my $self={
		filename    => undef,
		data        => '',
		_comments   => [],
		_strings    => [],
		_groups     => [],
		groups      => {},
		_groupless  => [],
		%opts,
	};
	bless($self,$class);
	return(undef) unless $self->init();
	return($self);
}

sub init {
	my $self=shift;
	if (defined $self->{filename} and (! $self->{data})) {
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
	}
	return(1);
}

sub find_comments_and_strings {
	my $self = shift;
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
			push @{$self->{_strings}},\%string;
		} else {
			my %comment=(
				o_b => $-[1],
				o_e => $+[1],
			);
			push @{$self->{_comments}},\%comment;
		}
	}
	# working copy
	my $d = $self->{data};
	# replace comments by same-length sequence of space
	foreach my $c (@{$self->{_comments}}) {
		my $len=$c->{o_e}-$c->{o_b};
		substr($d,$c->{o_b},$len) = ' ' x $len;
	}
	# replace strings by same-length sequence of underscores
	foreach my $s (@{$self->{_strings}}) {
		my $len=$s->{o_e}-$s->{o_b};
		substr($d,$s->{o_b},$len) = '_' x $len;
	}
	return($d);
}

sub find_groups {
	my $self=shift;
	while ($self->{data_cs} =~ m{(?:^|\n)\s*&(\S+)([^/]*)(/)}gs) {
		push @{$self->{_groups}},{
			name      => $1,
			o_name_b  => $-[1],
			o_name_e  => $+[1],
			o_vars_b  => $-[2],
			o_vars_e  => $+[2],
			o_b       => $-[1]-1,  # group begins with &
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
	# scan data_n for variables: name, optionally index, followed by '='
	while ($data_n=~m{,?\s+         ## variable assignments are separated by whitespace, optionally with a preceeding comma
			([a-zA-Z][^\(\s]+)      ## a fortran identifier starts with a letter
			\s*((?:\([^\)]*\)\s*?)*)## there may be more than one index statement attached to each variable
			\s*=\s*                 ## = separates variable and value, maybe enclosed by whitespace
		}gsx) {
		my %v = (
			name      => $1,
			o_name_b  => ($-[1]+$offset_b),
			o_name_e  => ($+[1]+$offset_b),
			index     => $self->parse_index($-[2]+$offset_b,$+[2]+$offset_b),
			o_index_b => ($-[2]+$offset_b),
			o_index_e => ($+[2]+$offset_b),
			value     => undef,
			o_value_b => ($+[0]+$offset_b),
			o_value_e => undef,
			o_decl_b  => ($-[0]+$offset_b),
		);
		push @vars,\%v;
	}
	if (@vars > 0) {
		# fill the end offset of values
		for (my $i=0; $i<$#vars; $i++) {
			$vars[$i]->{o_value_e}=$vars[$i+1]->{o_decl_b};
		}
		$vars[$#vars]->{o_value_e}=$offset_e;
		foreach my $v (@vars) {
			my $val=substr($self->{data_cs},$v->{o_value_b},$v->{o_value_e}-$v->{o_value_b});
			# strip whitespace at end of mask (originally comments), adjust offset accordingly
			if ($val =~ /\s+$/) {
				$v->{o_value_e}-=($+[0]-$-[0]);
			}
			# fill in the value
			$v->{value}=$self->find_value($v->{o_value_b},$v->{o_value_e});
		}
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
		push @value,$self->parse_value($old_e,$offset_e);
	}
	return(\@value);
}

sub parse_value {
	my ($self,$offset_b,$offset_e)=@_;
	my $data      = substr($self->{data},$offset_b,$offset_e-$offset_b);
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
		while (my ($vname,$v) = each %{$g->{vars}}) {
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

1;
