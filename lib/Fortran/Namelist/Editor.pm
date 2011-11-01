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
			vars      => $self->find_vars($-[2],$+[2]),
		};
	}
	return(1);
}

sub find_vars {
	my ($self,$offset_b,$offset_e)=@_;
	my $data_n      = substr($self->{data_cs},$offset_b,$offset_e-$offset_b);
	my $data_orig_n = substr($self->{data}   ,$offset_b,$offset_e-$offset_b);
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
			index     => $2,
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
			$v->{value}=substr($self->{data},$v->{o_value_b},$v->{o_value_e}-$v->{o_value_b});
		}
	}
	return(\@vars);
}
1;
