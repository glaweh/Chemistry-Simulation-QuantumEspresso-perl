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
use Fortran::Namelist::Editor::Group;
@Fortran::Namelist::Editor::ISA=qw{Fortran::Namelist::Editor::ContainerSpan};

sub init {
	my $self=shift;
	my %opts=%{pop()} if ($_[-1] and (ref $_[-1] eq 'HASH'));
	my $data=$opts{data};
	if (defined $opts{filename} and (! defined $data)) {
		# slurp in file
		if (open(my $fh,$opts{filename})) {
			local $/=undef;
			$data=<$fh>;
		} else {
			carp "Error opening file '$opts{filename}'";
			return(undef);
		}
	}
	$data='' unless (defined $data);
	$self->SUPER::init(undef,0,length($data));

	$self->{filename}    = $opts{filename};
	$self->{data}        = $data;

	# internal data structures
	$self->{_comments}   = [];
	$self->{_groups}     = [];
	$self->{groups}      = {};
	$self->{_groupless}  = [];
	$self->{indent}      = '';

	if ($self->{data}) {
		$self->{data_cs}=$self->find_comments_and_strings();
		$self->find_groups();
		$self->find_groupless();
		$self->find_indent();
	}
	return($self);
}
sub get_data {
	my ($self,$o_b,$o_e)=@_;
	my $r=reftype($o_b);
	if (defined $r) {
		return(undef) unless ($r eq 'HASH');
		$o_e=$o_b->{o_e};
		$o_b=$o_b->{o_b};
	}
	unless ((defined $o_b) and (defined $o_e)) {
		return($self->{data},$self->{data_cs}) if (wantarray);
		return($self->{data});
	}
	$o_b=$self->{o_b} unless (defined $o_b);
	$o_e=$self->{o_e} unless (defined $o_e);
	return(undef) if ($o_e > $self->{o_e});
	return(undef) if ($o_b > $self->{o_e});
	my $length = $o_e-$o_b;
	return(substr($self->{data},$o_b,$length),
		substr($self->{data_cs},$o_b,$length)) if (wantarray);
	return(substr($self->{data},$o_b,$length));
}
sub set_data {
	my ($self,$o_b,$o_e,$value,$value_cs)=@_;
	my $r=reftype($o_b);
	if (defined $r) {
		return(undef) unless ($r eq 'HASH');
		$o_e=$o_b->{o_e};
		$o_b=$o_b->{o_b};
	}
	$o_b=$self->{o_b} unless (defined $o_b);
	$o_e=$self->{o_e} unless (defined $o_e);
	return(undef) if ($o_e > $self->{o_e});
	return(undef) if ($o_b > $self->{o_e});
	my $length    = $o_e-$o_b;
	my $newlength = length($value);
	my $delta     = $newlength-$length;
	$value_cs     = $value unless (defined $value_cs);
	substr($self->{data},$o_b,$length)    = $value;
	substr($self->{data_cs},$o_b,$length) = $value_cs;
	if ($delta == 0) {
		return(0,0) if (wantarray);
		return(0);
	}
	my $adjust_id=$self->adjust_offsets($o_b+1,$delta);
	return($delta,$adjust_id) if (wantarray);
	return($delta);
}

sub find_comments_and_strings {
	my $self = shift;
	my (@strings,@comments);
	# working copy
	my $d = $self->get_data;
	# find all fortran !-style comments and quoted strings
	while ($d =~ m{
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
			my %comment=(
				o_b => $-[1],
				o_e => $+[1],
			);
			push @comments,\%comment;
		}
	}
	# replace comments by same-length sequence of space
	foreach my $c (@comments) {
		my $len=$c->{o_e}-$c->{o_b};
		substr($d,$c->{o_b},$len) = ' ' x $len;
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
	my (undef,$data_cs) = $self->get_data;
	while ($data_cs =~ m{(?:^|\n)[ \t]*(&\S+)[^/]*/}gs) {
		push @{$self->{_groups}},
			Fortran::Namelist::Editor::Group->new($self,$-[1],$+[0],$-[1],$+[1]);
	}
	foreach my $g (@{$self->{_groups}}) {
		my $name=$g->{name}->get;
		confess "group '$name' exists more than once" if (exists $self->{groups}->{$name});
		$self->{groups}->{$name}=$g;
	}
	return(1);
}

sub find_indent {
	my $self=shift;
	my %indent;
	foreach my $g (@{$self->{_groups}}) {
		$g->indent_histogram(\%indent);
	}
	if (%indent) {
		my @indentations=keys %indent;
		my @votes=values %indent;
		my @idx=sort { $votes[$b] <=> $votes[$a] } 0 .. $#votes;
		$self->{indent}=$indentations[$idx[0]];
	}
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
	my ($gl,$gl_cs) = $self->get_data($offset_b,$offset_e);
	if ($gl_cs =~ m{^\s*$}) {
		return(undef);
	}
	push @{$self->{_groupless}},{
		o_b   => $offset_b,
		o_e   => $offset_e,
		value => $gl,
	};
	return(1);
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
	my ($self,$group,@options)=@_;
	return($self->SUPER::get) unless (defined $group);
	return(undef) unless (exists $self->{groups}->{$group});
	return($self->{groups}->{$group}->get(@options));
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

sub refine_offset_back {
	my ($self,$position,$re) = @_;
	pos($self->{data_cs}) = $position;
	if ($self->{data_cs} =~ /$re\G/g) {
		return($-[1]);
	}
	return($position);
}

sub refine_offset_forward {
	my ($self,$position,$re) = @_;
	pos($self->{data_cs}) = $position;
	if ($self->{data_cs} =~ /\G$re/g) {
		return($+[1]);
	}
	return($position);
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
	$self->set_data($offset_b,$offset_b,$insert);
	my %group = (
			name      => Fortran::Namelist::Editor::Token->new($self,1+$offset_b,length($group_name)+1+$offset_b),
			o_b       => $offset_b,                       # group begins with &
			o_e       => length($group_name)+4+$offset_b, # end of NL group is /
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
	$self->set_data($group_ref,undef,'');
}

sub set {
	my ($self,$group,@setting)=@_;
	unless (exists $self->{groups}->{$group}) {
		$self->add_group($group);
	}
	return($self->{groups}->{$group}->set(@setting));
}

sub unset {
	my ($self,$group,@setting)=@_;
	unless (exists $self->{groups}->{$group}) {
		return(2);
	}
	return($self->{groups}->{$group}->unset(@setting));
}

1;
